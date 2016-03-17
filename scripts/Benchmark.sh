#!/bin/bash
set -eu
set -o pipefail

declare -a ROLES
#role-indexed associative arrays
declare -A ROLE_METADATA ROLE_COUNT ROLE_TARGET_DEVICE_TYPE ROLE_TARGET_CONFIG ROLE_TAG
WORKING_FILE="`mktemp`"

exec {STDOUT}>&1
exec 1>${WORKING_FILE}

#Convert board config file into target metadata
function target_metadata {
  local line
  local name
  local value
  local config_name="${1,,}"
  local config_file="`dirname $0`/../config/bench/boards/${config_name}.conf"
  if ! test -f "${config_file}"; then
    echo "No config file for '${config_name}'" >&2
    echo "Should have been at '${config_file}'" >&2
    exit 1
  fi

  #Output metadata from config file
  while read line; do
    echo "${line}" | grep -q '^[[:blank:]]*#' && continue
    echo "${line}" | grep -q '.=' || continue
    name="`echo ${line} | cut -d = -f 1`"
    value="`echo ${line} | cut -d = -f 2-`"
    ROLE_METADATA["$2"]="${ROLE_METADATA[$2]:-}\n      ${name}: '${value}'"
  done < "${config_file}"
}

function general_metadata {
  local tag
  for tag in "$@"; do
    if test -z "${!tag+x}"; then
      echo "Cannot read metadata from unset variable '${tag}'" >&2
      exit 1
    fi
    GENERAL_METADATA="${GENERAL_METADATA:-}\n      ${tag}: '${!tag}'"
  done
}

#This script has two 'entry points' - scripts/dispatch-benchmark.py and
#Jenkins jobs. Both of these entry points restrict the options for BENCHMARK
#and TARGET_CONFIG to only the valid set, so there is no need to validate these
#here beyond confirming that they have been set at all.
function validate {
  local x ret response_code
  ret=0


  ######################################################################################
  #Cases that must return early (bad input has consequences for the rest of validation)#
  ######################################################################################

  #paranoid htaccess case: we have to return early because later validate stages
  #may insecurely transmit credentials if input is bad
  if test -n "${DOWNLOAD_PASSWORD+x}"; then
    if echo "${DOWNLOAD_PASSWORD}" | grep -vq ':'; then
      echo "Bad format for DOWNLOAD_PASSWORD \"${DOWNLOAD_PASSWORD}\": must be user:password" >&2
      ret=1
    fi

    #Check both that we are using https, and that we are using the same server for all cases
    local remote_ip
    for x in TOOLCHAIN SYSROOT PREBUILT; do
      test -z "${!x:-}" && continue
      if echo "${!x}" | grep -qv '^http://'; then #TODO add an s
        echo "Must use https protocol with DOWNLOAD_PASSWORD" >&2
        echo "  - ${x} has URL \"${!x}\"" >&2
        ret=1
      fi
      if test -z "${remote_ip:-}"; then
        remote_ip="`echo ${!x} | sed 's#^http://\([^/]\+\).*#\1#'`" #TODO add an s
        if test -z "${remote_ip:-}" ||
           test x"${remote_ip}" = x"${!x}"; then
          echo "Unable to determine server for $x from URL \"${!x}\"" >&2
          ret=1
        fi
      elif test  x"`echo ${!x} | sed 's#^http://\([^/]\+\).*#\1#'`" != x"${remote_ip}"; then #TODO add an s
        echo "All downloadables (TOOLCHAIN, SYSROOT, PREBUILT) must come from same server if DOWNLOAD_PASSWORD is set." >&2
        echo "  - Otherwise we would transmit the credentials to multiple servers, some of which may be untrusted." >&2
        ret=1
      fi
    done
    if test "${ret}" -ne 0; then
      return ${ret} #Must do early return here, as later validation steps will transmit the credentials
    fi
  fi
  #Paranoid ssh key case does not need validation, as there is no risk of transmitting secrets to untrusted places


  ###############################################
  #Cases that must be corrected by user (errors)#
  ###############################################

  for x in TARGET_CONFIG BENCHMARK LAVA_SERVER; do
    if test -z "${!x:-}"; then
      echo "${x} must be set" >&2
      ret=1
    fi
  done
  if test -n "${PREBUILT:-}"; then
    for x in TOOLCHAIN SYSROOT COMPILER_FLAGS MAKE_FLAGS; do
      if test -n "${!x:-}"; then
        echo "Must not specify $x with PREBUILT" >&2
        ret=1
      fi
    done
  fi
  if test -z "${PREBUILT:-}" &&
     test -z "${TOOLCHAIN:-}"; then
    echo "Exactly one of TOOLCHAIN and PREBUILT must be set" >&2
    ret=1
  fi

  if test -n "${DOWNLOAD_KEY:-}" ||
     test -n "${DOWNLOAD_HOST:-}"; then
    if test -z "${DOWNLOAD_KEY:-}"; then
      echo "DOWNLOAD_HOST is set, but DOWNLOAD_KEY is unset. Must set both or neither." >&2
      ret=1
    elif test -z "${DOWNLOAD_HOST:-}"; then
      echo "DOWNLOAD_KEY is set, but DOWNLOAD_HOST is unset. Must set both or neither." >&2
      ret=1
    elif test -n "${DOWNLOAD_PASSWORD:-}"; then
      echo "Cannot set DOWNLOAD_PASSWORD alongside either of DOWNLOAD_HOST and DOWNLOAD_KEY." >&2
      ret=1
    fi
  fi

  #Far from foolproof, but can catch blatantly wrong URL early
  for x in TOOLCHAIN SYSROOT PREBUILT; do
    test -z "${!x:-}" && continue
    echo "${!x}" | grep -qv '^https\?://' && continue #Assume that this is an rysnc path, we don't (yet) try to validate those in advance
    response_code=`curl -w %{response_code} --output /dev/null --silent --head --fail "${!x}"` && continue
    case $? in
      3) continue;; #Malformed URL - could be a local path
      6) continue;; #Could not resolve host - might be a host we cannot see from here
      22)
        if test x"${response_code}" = x401; then
          if test -z "${DOWNLOAD_PASSWORD:-}"; then
            echo "Access to ${x} (\"${!x}\") requires password authentication (401), but DOWNLOAD_PASSWORD is not set" >&2
            ret=1
          else #We'll send these credentials to this server in config/lava/host_session, so no additional risk in doing it here
            response_code=`curl -u "${DOWNLOAD_PASSWORD}" -w %{response_code} --output /dev/null --silent --head --fail "${!x}"` && continue
            echo "Access to ${x} (\"${!x}\") denied with supplied credentials (response code ${response_code})" >&2
            echo "  - Credentials were transmitted to server in \"${!x}\", you should consider whether they may be compromised" >&2
           ret=1
          fi
        else
          echo "Could not find ${x} (\"${!x}\" gives response code ${response_code})" >&2
          ret=1
        fi
     ;;
      *) echo "${x} URL \"${!x}\" gives curl error $? (response code ${response_code})" >&2; ret=1;;
    esac
  done

  #Need to be careful with this one - a toolchain with no triple might still
  #generate code for the target named by the triple (e.g. /usr/bin/gnu on a
  #Juno board). Equally, no triple means 'native', and native code might be
  #generated by a toolchain with an explicit triple.
  #But we can catch the case where a triple shows up on both sides and does not
  #match.
  if test -n "${TRIPLE:-}"; then
    if test "${TRIPLE}" = aarch64-linux-gnu; then
      if echo "${TOOLCHAIN:-}" | grep -q arm-linux-gnueabihf; then
        echo "TOOLCHAIN ${TOOLCHAIN} seems incompatible with TRIPLE ${TRIPLE}" >&2
        ret=1
      fi
    elif test "${TRIPLE}" = arm-linux-gnueabihf; then
      if echo "${TOOLCHAIN:-}" | grep -q aarch64-linux-gnu; then
        echo "TOOLCHAIN ${TOOLCHAIN} seems incompatible with TRIPLE ${TRIPLE}" >&2
        ret=1
      fi
    fi
  fi

  if test `echo ${HOST_TAG:-} | wc -w` -gt 1; then
    echo "HOST_TAG contains multiple values: ${HOST_TAG}" >&2
    ret=1
  fi


  #####################################################
  #Cases that can be fixed up automatically (warnings)#
  #####################################################

  for x in LAVA_SERVER BUNDLE_SERVER; do
    if test -n "${!x:-}"; then
      if echo "${!x}" | grep -q '://'; then
        eval ${x}="${!x/#*:\/\/}"
        echo "${x} must not specify protocol" >&2
        echo "Stripped ${x} to ${!x}" >&2
      fi
      if echo "${!x}" | grep -q '/RPC2$'; then
        eval ${x}="${!x}/"
        echo "${x} must have '/' following /RPC2" >&2
        echo "Added trailing '/' to ${x}" >&2
      elif ! echo "${!x}" | grep -q '/RPC2/$'; then
        eval ${x}="${!x}/RPC2/"
        echo "${x} must end with /RPC2/" >&2
        echo "Added /RPC2/ to ${x}" >&2
      fi
    fi
  done
  if test -n "${BUNDLE_STREAM:-}"; then
    if test "${BUNDLE_STREAM: -1}" != /; then
      BUNDLE_STREAM="${BUNDLE_STREAM}/"
      echo "BUNDLE_STREAM must end with '/'" >&2
      echo "Added '/' to end of BUNDLE_STREAM" >&2
    fi
  fi
  if test -z "${TIMEOUT:-}"; then
    if test x"${BENCHMARK}" = x"CPU2000" ||
       test x"${BENCHMARK}" = x"CPU2006"; then
      TIMEOUT=604800
    elif test x"${BENCHMARK}" = x"Coremark-Pro"; then
      TIMEOUT=14400
    elif test x"${BENCHMARK}" = x"fakebench"; then
      TIMEOUT=3600
    else
      TIMEOUT=86400
      echo "Unknown benchmark '${BENCHMARK}'" >&2
      echo "Set TIMEOUT to 24 hours" >&2
    fi
  fi

  #Both fatal and warning cases that depend on the validation/processing above
  if test x"${LAVA_SERVER}" = xlava.tcwglab/RPC2/ ||
     test x"${LAVA_SERVER}" = x192.168.16.2/RPC2/; then
    TRUST="${TRUST:-Trusted}"
    if test x"${TRUST}" != xTrusted; then
      echo "User has overriden TRUST to ${TRUST} for trustable instance" >&2
    fi
    if test -n "${PUBKEY_HOST:-}"; then
      echo "PUBKEY_HOST is meaningless for trusted run: will ignore it" >&2
    fi
    PUBKEY_TARGET="${PUBKEY_TARGET:-ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDVsYkArH+s18nFxzy6zVWMg45uN4oQm5WxjVkZ/PxjyzPbnfTjRgyaqKDUbxUagWX76DCSFHftlKDAllYpAuvGrCsJtVOkSqrkrB8PMZNIsy+4fiL/j+qjLX9bEq0TKpf9aVK6xx2enl9NX8CvOwvxSnqrkevyeuMrw1oULnwN9qiliHmV0MSzWE+U3Y8VOyFbhhgAiy9/ud5sklurJebs/B7Q1w0LrA+WiTwmVkrumauX+Om24IU1MOxOJHcIao+hDyb87Oo2Ca8uXBeWEVPHh8kwddm5FHOe3KbT3VhuFhN5U/7h4xAgdp8YFXRJL/xxbZ8+nggkLS6Zx0sDbuUb}"
  else
    TRUST="${TRUST:-None}"
    if test x"${TRUST}" != xNone; then
      echo "User has overriden TRUST to ${TRUST} for untrustable instance" >&2
    fi
    for x in PUBKEY_HOST PUBKEY_TARGET; do
      if test -x "${!x:-}"; then
        echo "${x} must be set for untrusted sessions" >&2
        ret=1
      fi
    done
  fi

  return ${ret}
}

function init_targets {
  local role device_type target_count tag default_tag
  target_count=`echo ${TARGET_CONFIG} | wc -w`
  for target_config in ${TARGET_CONFIG}; do
    if echo "${target_config}" | grep -q ':'; then
      role="target-${target_config%:*}"
      target_config="${target_config#*:}"
      device_type="${target_config}"
    else
      role="target-${target_config}"
      #target_config is already correct
      device_type="${target_config}"
    fi

    #TODO: Should invent a standard way of handling this.
    #      Cannot just make it what '-' means in general, because of panda-es.
    if test x"${device_type%%-*}" = xjuno; then
      device_type='juno'
    fi

    ROLE_COUNT["${role}"]=$((${ROLE_COUNT["${role}"]:-0} + 1))
    if test -z "${ROLE_TARGET_DEVICE_TYPE[${role}]:-}"; then
      ROLE_TARGET_DEVICE_TYPE["${role}"]="${device_type}"
    elif test x"${ROLE_TARGET_DEVICE_TYPE[${role}]}" != x"${device_type}"; then
      echo "Multiple device types for role '${role}'" >&2
      exit 1
    fi
    if test -z "${ROLE_TARGET_CONFIG[${role}]:-}"; then
      ROLE_TARGET_CONFIG["${role}"]="${target_config}"
    elif test x"${ROLE_TARGET_CONFIG[${role}]}" != x"${target_config}"; then
      echo "Multiple configs for role '${role}'" >&2
      exit 1
    fi
    target_metadata "${target_config}" "${role}"
  done
  ROLES=("${!ROLE_COUNT[@]}")

  #Find default tag, if any
  for tag in ${TARGET_TAGS:-}; do
    if echo "${tag}" | grep -vq ':'; then
      if test -z "${default_tag:-}"; then
        default_tag="${tag}"
      else
        echo "Multiple default target tags: '${tag}' and ${default_tag}'" >&2
        exit 1
      fi
    fi
  done

  #Assign specific tags
  for tag in ${TARGET_TAGS:-}; do
    echo "${tag}" | grep -vq ':' && continue
    role="target-${tag%%:*}"
    tag="${tag#*:}"
    if test -z "${ROLE_COUNT[${role}]:-}"; then
      echo "Tag '${tag}' provided for non-existent role '${role}'" >&2
      exit 1
    fi
    if test -n "${ROLE_TAG[${role}]:-}"; then
      echo "Tags '${tag}' and '${ROLE_TAG[${role}]}' provided for role '${role}'" >&2
      exit 1
    fi
    ROLE_TAG["${role}"]="${tag}"
  done

  #Assign default tags
  if test -n "${default_tag:-}"; then
    for role in "${ROLES[@]}"; do
      if test -z "${ROLE_TAG[${role}]:-}"; then
        ROLE_TAG["${role}"]="${default_tag}"
      fi
    done
  fi
}

function deploy_for_device_type {
  declare -A cmd parts #also local

  cmd[arndale]='deploy_linaro_image'
  cmd[dummy-ssh]='dummy_deploy'
  cmd[juno]='deploy_linaro_image'
  cmd[kvm]='deploy_linaro_image'
  cmd[mustang]='deploy_linaro_kernel'
  cmd[panda-es]='deploy_linaro_image'

  parts[arndale]="image: 'http://people.linaro.org/~bernie.ogden/arndale/arndale.img'"
  parts[dummy-ssh]="target_type: 'ubuntu'"
  parts[juno]="image: 'http://people.linaro.org/~bernie.ogden/juno-precooked.img.gz'"
  parts[kvm]="image: 'http://images.validation.linaro.org/ubuntu-14-04-server-base.img.gz'"
  parts[mustang]="dtb: 'http://kernel-build.s3-website-eu-west-1.amazonaws.com/next-20151022/arm64-defconfig/dtbs/apm-mustang.dtb'
      kernel: 'http://kernel-build.s3-website-eu-west-1.amazonaws.com/next-20151022/arm64-defconfig/uImage-mustang'
      nfsrootfs: 'http://people.linaro.org/~bernie.ogden/linaro-utopic-developer-20150319-701.tar.gz'"
  parts[panda-es]="hwpack: 'http://releases.linaro.org/14.05/ubuntu/panda/hwpack_linaro-panda_20140525-654_armhf_supported.tar.gz'
      rootfs: 'http://releases.linaro.org/14.05/ubuntu/panda/linaro-trusty-developer-20140522-661.tar.gz'"

  if test -z "${cmd[$1]:-}"; then
    echo "${FUNCNAME}: Unknown device type '$1'" >&2
    exit 1
  fi

  cat <<EOF
  - command: '${cmd[$1]}'
    parameters:
      role: '$2'
      ${parts[$1]}
EOF
}

function host_session_for_device_type {
  declare -A session #also local
  session[arndale]=host-session-multilib.yaml
  session[dummy-ssh]=host-session-persist-safe.yaml
  session[juno]=host-session-no-multilib.yaml
  session[kvm]=host-session-multilib.yaml
  #session[mustang]= #Deliberately omitted as we are running OE on the mustang and so can't install missing packages.
  session[panda-es]=host-session-no-multilib.yaml #Bit of a guess - the pandas are unreliable and this isn't worth the effort to test.

  if test -z "${session[$1]:-}"; then
    echo "${FUNCNAME}: Unknown device type '$1'" >&2
    exit 1
  fi

  echo "config/bench/lava/${session[$1]}"
}

function target_session_for_device_type {
  declare -A session #also local
  session[arndale]=target-session-tools.yaml
  #session[dummy-ssh]= #Deliberately omitted until we either have non-persistent dummy targets, or target jobs that do not mess with persistent state
  session[juno]=target-session-tools.yaml
  session[kvm]=target-session-tools.yaml
  session[mustang]=target-session.yaml
  session[panda-es]=target-session-tools.yaml

  if test -z "${session[$1]:-}"; then
    echo "${FUNCNAME}: Unknown device type '$1'" >&2
    exit 1
  fi

  echo "config/bench/lava/${session[$1]}"
}

function deploy_targets {
  local role target_device_type
  for role in "${ROLES[@]}"; do
    deploy_for_device_type "${ROLE_TARGET_DEVICE_TYPE[${role}]}" "${role}"
    echo "    metadata_${role}:"
  done
}

function host_session {
  local host_session
  #Determine host session here, so that -e can pick up failure
  host_session="`host_session_for_device_type ${HOST_DEVICE_TYPE}`"
  cat << EOF
  - command: 'lava_test_shell'
    parameters:
      role: 'host'
      timeout: ${TIMEOUT}
      testdef_repos:
        - git-repo: '${TESTDEF_REPO}'
          revision: '${TESTDEF_REVISION}'
          testdef: '${host_session}'
          parameters:
            BENCHMARK: '${BENCHMARK}'
            TOOLCHAIN: '${TOOLCHAIN:-None}'
            TRIPLE: '${TRIPLE:-None}'
            SYSROOT: '${SYSROOT:-None}'
            RUN_FLAGS: '${RUN_FLAGS:-None}'
            COMPILER_FLAGS: '${COMPILER_FLAGS:-None}'
            MAKE_FLAGS: '${MAKE_FLAGS:-None}'
            PREBUILT: '${PREBUILT:-None}'
            BENCH_DEBUG: ${BENCH_DEBUG}
            TRUST: '${TRUST}'
            DOWNLOAD_PASSWORD: '${DOWNLOAD_PASSWORD:-None}'
            DOWNLOAD_HOST: '${DOWNLOAD_HOST:-None}'
            DOWNLOAD_KEY: '${DOWNLOAD_KEY:-None}'
EOF
  if test x"${TRUST}" = x'None'; then
    cat <<EOF
            PUB_KEY: '${PUBKEY_HOST}'
EOF
  fi
}

function target_session {
  local target_session
  for role in "${ROLES[@]}"; do
    #Determine target session here, so that -e can pick up failure
    target_session="`target_session_for_device_type ${ROLE_TARGET_DEVICE_TYPE[${role}]}`"
    cat << EOF
  - command: 'lava_test_shell'
    parameters:
      role: '${role}'
      timeout: ${TIMEOUT}
      testdef_repos:
        - git-repo: '${TESTDEF_REPO}'
          revision: '${TESTDEF_REVISION}'
          testdef: '${target_session}'
          parameters:
            CONFIG: '${ROLE_TARGET_CONFIG[${role}]}'
            PUB_KEY: '${PUBKEY_TARGET}'
EOF
  done
}

validate #Fails on error due to set -e (which is what we want)

#Defaults
LAVA_USER="${LAVA_USER:-${USER}}"
LAVA_JOB_NAME="${LAVA_JOB_NAME:-${BENCHMARK}-${LAVA_USER}}"
HOST_DEVICE_TYPE="${HOST_DEVICE_TYPE:-dummy-ssh}"
TESTDEF_REVISION="${TESTDEF_REVISION:-benchmarking}"
TESTDEF_REPO="${TESTDEF_REPO:-https://git.linaro.org/toolchain/abe}"
BUNDLE_SERVER="${BUNDLE_SERVER:-${LAVA_SERVER}}"
BUNDLE_STREAM="${BUNDLE_STREAM:-/private/personal/${LAVA_USER}/}"
BENCH_DEBUG="${BENCH_DEBUG:-1}"

#By the time these parameters reach LAVA, None means unset
#Unset is not necessarily the same as empty string - for example,
#COMPILER_FLAGS="" may result in overriding default flags in makefiles
TOOLCHAIN="${TOOLCHAIN:-None}"
TRIPLE="${TRIPLE:-None}"
SYSROOT="${SYSROOT:-None}"
RUN_FLAGS="${RUN_FLAGS:-None}"
COMPILER_FLAGS="${COMPILER_FLAGS:-None}"
MAKE_FLAGS="${MAKE_FLAGS:-None}"
PREBUILT="${PREBUILT:-None}"

#Initialize data structures
init_targets
general_metadata LAVA_JOB_NAME LAVA_USER BENCHMARK TOOLCHAIN TRIPLE SYSROOT \
                 RUN_FLAGS COMPILER_FLAGS MAKE_FLAGS PREBUILT TARGET_CONFIG \
                 TESTDEF_REPO TESTDEF_REVISION TIMEOUT ${METADATA:-}

#Job header
cat <<EOF
job_name: '${LAVA_JOB_NAME}'
timeout: ${TIMEOUT}
actions:
EOF

#Host deploy stanza
deploy_for_device_type "${HOST_DEVICE_TYPE}" host

#Target deploy stanza(s)
deploy_targets

#Host session stanza
host_session

#Target_session_stanza(s)
target_session

#Submission stanza
cat << EOF
  - command: 'submit_results'
    parameters:
      server: 'https://${BUNDLE_SERVER}'
      stream: '${BUNDLE_STREAM}'
EOF

#Device reservation stanzas
cat << EOF
device_group:
  - count: 1
    device_type: '${HOST_DEVICE_TYPE}'
    role: 'host'
EOF
if test -n "${HOST_TAG:-}"; then
cat << EOF
    tags:
      - ${HOST_TAG}
EOF
fi
for role in "${ROLES[@]}"; do
  cat << EOF
  - count: ${ROLE_COUNT["${role}"]}
    device_type: '${ROLE_TARGET_DEVICE_TYPE["${role}"]}'
    role: '${role}'
EOF
  if test -n "${ROLE_TAG[${role}]:-}"; then
  cat << EOF
    tags:
      - ${ROLE_TAG[${role}]}
EOF
  fi
done
unset role

#Fill in metadata
for role in "${ROLES[@]}"; do
  if test -n "${ROLE_METADATA[${role}]:-}${GENERAL_METADATA}"; then
    #The $ before the enquoted string is a little shell (bash only?) magic to
    #render \n into newline.
    sed -i $"s#metadata_${role}:#metadata:${GENERAL_METADATA//\"/\\\"}${ROLE_METADATA[${role}]//\"/\\\"}#" "${WORKING_FILE}"
  else
    sed -i "/metadata_${role}:/d" "${WORKING_FILE}"
  fi
done
unset role

exec 1>&${STDOUT}
cat "${WORKING_FILE}"
rm -f "${WORKING_FILE}"
