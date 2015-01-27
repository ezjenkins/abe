set -o pipefail
set -o nounset

function get_addr
{
  local hostname="${1:-localhost}"
  local listener_addr
  if test x"${hostname}" = xlocalhost; then
    listener_addr="`hostname -I`"
  else
    listener_addr="`ssh -F /dev/null -o PasswordAuthentication=no -o PubkeyAuthentication=yes ${hostname} 'hostname -I'`"
  fi
  if test $? -ne 0; then
    echo "Failed to run 'hostname -I' on ${hostname}" 1>&2
    return 1
  fi

  #We only try to support IPv4 for now
  listener_addr="`echo ${listener_addr} | tr ' ' '\n' | grep '^\([[:digit:]]\{1,3\}\.\)\{3\}[[:digit:]]\{1,3\}$'`"
  if test $? -ne 0; then
    echo "No IPv4 address found, aborting" 1>&2
    return 1
  fi

  #We don't try to figure out what'll happen if we've got multiple IPv4 interfaces
  if test "`echo ${listener_addr} | wc -w`" -ne 1; then
    echo "Multiple IPv4 addresses found, aborting" 1>&2
    return 1
  fi

  echo "${listener_addr}" | sed 's/^[[:blank:]]*//' | sed 's/[[:blank:]]*$//'
}

#Return 0 if we're inside the lava network
#Return 1 if we're outside the lava network
#Return 2 if we don't know where we are
#Typically, 2 will be returned if we can't ssh into the hackbox. This tends
#to mean we're not configured to do so and could happen both inside and outside
#the LAVA network.
function lava_network
{
  local hackbox_mac

  hackbox_mac="`ssh -F /dev/null -o PasswordAuthentication=no -o PubkeyAuthentication=yes ${1:+${1}@}lab.validation.linaro.org 'cat /sys/class/net/eth0/address'`"
  if test $? -ne 0; then
    echo "Failed to get hackbox mac" 1>&2
    echo "Tried: ssh -F /dev/null -o PasswordAuthentication=no -o PubkeyAuthentication=yes ${1:+${1}@}lab.validation.linaro.org 'cat /sys/class/net/eth0/address'" >&2
    return 2 #We couldn't get the mac, stop trying to figure out where we are
  fi
  arp 10.0.0.10 | grep -q "${hackbox_mac}";
  if test $? -eq 0; then
    return 0
  else
    return 1
  fi
}

function lava_user
{
  local usr="${USER}"
  if echo "$1" | grep -q '^http'; then
    echo "LAVA URL must exclude protocol (e.g. http://, https://)" 1>&2
    return 1
  fi
  if echo "$1" | grep -Eq '^.+@'; then
    usr="${1/@*}"
    usr="${usr/:*}"
  fi
  echo "${usr}"
}

function lava_server
{
  if echo "$1" | grep -q '^http'; then
    echo "LAVA URL must exclude protocol (e.g. http://, https://)" 1>&2
    return 1
  fi
  if echo "$1" | grep -Eq '^.+@'; then
    echo "$1" | sed 's/[^@]*@//'
  else
    echo "$1"
  fi
}

#Attempt to use read to discover whether there is a record to read from the producer
#If we time out, check to see whether the producer still seems to be alive.
#We can check more than one pid, if we have visibility of some other process(s) that we
#would also like to monitor while we wait to read something. If any of these
#processes seem dead then return 2, otherwise keep trying to read.
#Once we've established that there seems to be a record, try to read it with a
#read timeout. If we fail to read within read_timeout, return 1 to indicate
#read failure - but the producer may still be alive in this case.
#Can also set a deadline - bgread will return 3 if it hasn't seen any new output
#before deadline expires. deadline is only checked at read_timeout intervals.
#Typical invocation: foo="`bgread ${child_pid} <&3`"
#Invocation with read checks every 5 seconds, failure after 2 minutes and two
#pids to monitor:
#foo="`bgread -T 120 -t 5 ${child_pid} ${other_pid} <&3`"
function bgread
{
  OPTIND=1
  local read_timeout=60
  local deadline=
  local pid

  while getopts T:t: flag; do
    case "${flag}" in
      t) read_timeout="${OPTARG}";;
      T) deadline="$((${OPTARG} + `date +%s`))";;
      *)
         echo "Bad arg" 1>&2
         return 1
      ;;
    esac
  done
  shift $((OPTIND - 1))

  if test $# -eq 0; then
    echo "No pid(s) to poll!" 1>&2
    return 1
  fi
  local buffer=''
  local line=''

  #We have to be careful here. If the read times out when there was a partial
  #record on the fifo then the part that has been read just gets discarded. We
  #can avoid this problem by using -N to ensure that we read the minimal amount
  #and DO NOT discard it. -N 0 might be intuited to do the right thing, but is
  #arguably undefined behaviour and empirically doesn't work.
  #Read 1 char then timeout if it isn't a delimiter: buffer is the char, exit code 0 OR
  #Read the delimiter, don't timeout: buffer is empty, exit code 0 OR
  #Fail to read any chars coz there aren't any, then timeout: buffer is empty, exit code 1
  while ! read -N 1 -t "${read_timeout}" buffer; do
    for pid in "$@"; do
      kill -0 "${pid}" > /dev/null 2>&1 || return 2
    done
    if test x"${deadline:-}" != x; then
      if test `date +%s` -ge ${deadline}; then
        echo "bgread timed out" 1>&2
        return 3
      fi
    fi
  done

  #If we get here, we managed to read 1 char. If we have a null string just
  #return it (the record was empty). Otherwise, assume the rest of the record is ready to be read,
  #especially within the generous timeout that we allow.
  if test x"${buffer:-}" != x; then
    read -t 60 line
    if test $? -ne 0; then
      echo "Record did not complete" 1>&2
      return 1
    fi
  fi
  echo "${buffer}${line}"
  return 0
}

#Use ping to perform a traceroute-like check of route to some target
#It's probably not guaranteed that other protocols (or even future pings) will
#take the same route, this is just a conservative sanity check.
function check_private_route
{
  local myaddr
  local pingout
  local ttl
  local retry

  if test x"${1:-}" = x; then
    echo "check_private_route requires a parameter" 1>&2
    return 1
  fi

  #Extended regexps (use grep -E)
  local block24='10\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+'
  local block20='172\.(1[6-9]|2[0-9]|3[0-1])\.[[:digit:]]+\.[[:digit:]]+'
  local block16='192\.168\.[[:digit:]]+\.[[:digit:]]+'

  myaddr="`get_addr`"
  if test $? -ne 0; then
    echo "Cannot get a usable IP address to check route" 1>&2
    return 1
  fi

  #Check we're on something in a private network to start with
  if ! echo "${myaddr}" | grep -Eq "^(${block24}|${block20}|${block16})$"; then
    echo "Own IP address ${myaddr} does not match any known private network range" 1>&2
    return 1
  fi

  #Check every stop along the way to target. DO NOT check target itself - assume
  #that we don't hop off our network even if its IP appears to be non-private.
  #This is a crude, but generic and unprivileged, way of doing traceroute - what
  #we really want is the routing tables, I think.
  for ttl in {1..10}; do
    #This thing sometimes fails spuriously - I can't fathom why, so we retry
    #a few times. Sigh.
    for retry in {1..5}; do
      pingout="`ping -n -t ${ttl} -c 1 $1`"
      if test $? -eq 0; then
        return 0 #We've reached the target
      fi
      echo "${pingout}" | grep -Eq "^From (${block24}|${block20}|${block16}) icmp_seq=1 Time to live exceeded$"
      if test $? -eq 0; then
        continue 2
      fi
    done
    echo "Surprising stop on hop ${ttl} on route to benchmark target: '${pingout}'" 1>&2
    return 1
  done

  echo "Failed to reach benchmark target within ${ttl} hops" 1>&2
  return 1
}