#!/bin/bash
#Be aware that LAVA likes TEST_CASE_ID (the first parameter to ltc) to have no
#spaces. ltc passes the first hurdle for handling spaces, but the LAVA UI seems
#to truncate at the first space. And who knows what might be getting mixed up
#elsewhere in the system if we put spaces in the ID.

set -eu
set -o pipefail

declare -A verificationCount
declare -A performanceCount
declare -A medianCount

error=1

function ltc {
  #Funky quoting to help out syntax highlighters
  ${TESTING:+echo} 'lava-test-case' "$@"
}

function ltra {
  #Funky quoting to help out syntax highlighters
  ${TESTING:+echo} 'lava-test-run-attach' "$@"
}

function exit_handler {
  exit ${error}
}

#This only works in some cases, keeping it as it is useful when it works,
#not wasting any more time trying to understand it.
#One fail case is:
#function ename { name; }
#ename
#This exits, but produces no stacktrace.
function err_handler {
  exec 1>&2
  echo "ERROR ${error}"
  echo "Stack trace, excluding subshells:"
  local frame=0
  while caller ${frame}; do
    frame=$((frame + 1))
  done
}

trap exit_handler EXIT
trap err_handler ERR

function header {
  test x"$1" = xUID
}

function comment {
  test "${1:0:1}" = '#'
}

function verification {
  test x"$1" = x'#Results' && test x"$3" = xverification
}

function performance {
  test x"$1" = x'#Results' && test x"$3" = xperformance
}

function median {
  test x"$1" = x'#Median'
}

function pass {
  test $6 -eq 0
}

function name {
  echo "$3" | tr ' ' _
}

function runtime {
  echo $7
}

function it_per_sec {
  echo $9
}

function code_size {
  shift
  echo $9
}

function data_size {
  shift 2
  echo $9
}

function report_measured {
  local name it runtime it_ps
  name="$1"
  it="$2"
  shift 2
  if pass "$@"; then
    runtime="`runtime $@`"
    it_p_s="`it_per_sec $@`"
    ltc "${name}[${it}]:time" --result pass --units seconds --measurement "${runtime}"
    ltc "${name}[${it}]:rate" --result pass --units "it/s" --measurement "${it_p_s}"
  else
    ltc "${name}[${it}]" --result fail
  fi
}

function marks_name {
  echo "$1" | tr ' ' _
}

function marks_score {
  echo $2
}

function marks_units {
  echo $3
}

function report_marks {
  local markslog="$1"
  if test `wc -l ${markslog} | cut -d ' ' -f 1` -eq 2; then
    line="`sed -n 2p ${markslog} | tr , ' '`"
    ltc "`marks_name ${line}`" --result pass --units "`marks_units ${line}`" \
        --measurement "`marks_score ${line}`"
  else
    echo "Wrong number of lines in marks file" >&2
    false
  fi
}

#Metadata

run="$1"

#Attach raw output - do this first so that we have something to debug if
#later code that scrapes the raw output should fail.
pushd . > /dev/null
cd "${run}"/..
ltra RETCODE
ltra stdout
ltra stderr
cd - > /dev/null
cd "${run}"
ltra linarobenchlog
cd builds
if test -e */*/cert; then
  for x in `find */*/cert -type f | sort`; do
    ltra "$x"
  done
fi
for x in `find */*/logs -type f | sort`; do
  ltra "$x"
done
popd > /dev/null

for target in `cd "${run}/builds"; ls`; do
  for toolchain in `cd "${run}/builds/${target}"; ls`; do
    log="${run}/builds/${target}/${toolchain}/logs/${target}.${toolchain}.log"
    if ! test -e "${log}"; then
      continue
    fi

    #slurp results file
    line=("")
    while IFS='' read -r l; do line=("${line[@]}" "${l}"); done < "${log}"
    line_max=$((${#line[@]} - 1))

    #Log individual test results
    iteration=0
    i=0
    while test $i -lt ${line_max}; do
      i=$((i+1))
      if header ${line[$i]}; then
        continue
      elif verification ${line[$i]}; then
        i=$((i+1))
        name="`name ${line[$i]}`"
        verificationCount["${name}"]=$((${verificationCount["${name}"]:-0} + 1))
        if pass ${line[$i]}; then
          ltc "${name}[verification[${verificationCount[${name}]}]]" --result pass
        else
          ltc "${name}[verification[${verificationCount[${name}]}]]" --result fail
        fi

        #Log sizes off the first verification run, as these should only be constant
        if test ${verificationCount["${name}"]} -eq 1; then
          ltc "${name}[code_size]" --result pass --units 'bytes' --measurement "`code_size ${line[$i]}`"
          ltc "${name}[data+bss_size]" --result pass --units 'bytes' --measurement "`data_size ${line[$i]}`"
        fi
      elif performance ${line[$i]}; then
        while ! comment ${line[$((i+1))]}; do
          i=$((i+1))
          name="`name ${line[$i]}`"
          performanceCount["${name}"]=$((${performanceCount["${name}"]:-0} + 1))
          report_measured "${name}" "iteration[${performanceCount["${name}"]}]" ${line[$i]}
        done
      elif median ${line[$i]}; then
        i=$((i+1))
        name="`name ${line[$i]}`"
        medianCount["${name}"]=$((${medianCount["${name}"]:-0} + 1))
        report_measured "${name}" "median[${medianCount[${name}]}]" ${line[$i]}
      fi
    done

    #Log ProMarks
    markslog="${run}/builds/${target}/${toolchain}/logs/${target}.${toolchain}.mark"
    if ! test -e "${markslog}"; then
      markslog="${run}/builds/${target}/${toolchain}/logs/${target}.${toolchain}.noncert_mark"
    fi
    if test -e "${markslog}"; then
      report_marks "${markslog}"
    fi
  done
done

error=0

