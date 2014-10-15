#!/bin/sh
# 
#   Copyright (C) 2014 Linaro, Inc
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

# These functions are roughly based on the python script the LAVA team uses. That script
# is available at:
# https://git.linaro.org/lava-team/lava-ci.git/blob_plain/HEAD:/lava-project-ci.py

# https://review.openstack.org/Documentation/cmd-index.html

    # ssh -p 29418 robert.savoye@git.linaro.org gerrit version
    # this uses the git commit SHA-1
    # ssh -p 29418 robert.savoye@git.linaro.org gerrit review --code-review 0 -m "foo" a87c53e83236364fe9bc7d5ffdbf3c307c64707d
    # ssh -p 29418 robert.savoye@git.linaro.org gerrit review --project toolchain/cbuild2 --code-review 0 -m "foobar" a87c53e83236364fe9bc7d5ffdbf3c307c64707d

# The number used for code reviews looks like this, it's passed as a string to
# these functions:
#   -2 Do not submit
#   -1 I would prefer that you didn't submit this
#   0 No score
#   +1 Looks good to me, but someone else must approve
#   +2 Looks good to me, approved


# ssh -p 29418 robert.savoye@git.linaro.org gerrit review --project toolchain/cbuild2 --code-review "+2" -m "foobar" 55957eaff3d80d854062544dea6fc0eedcbf9247 --submit

    # local revision="@`cd ${srcdir} && git log --oneline | head -1 | cut -d ' ' -f 1`"

# These extract_gerrit_* functions get needed information from a .gitreview file.

# Extract info we need from a ,gitreview file, which sets the globals
gerrit_info()
{
    local srcdir=$1
    extract_gerrit_host ${srcdir}
    extract_gerrit_port ${srcdir}
    extract_gerrit_project ${srcdir}
    extract_gerrit_username ${srcdir}
}

extract_gerrit_host()
{
    local srcdir=$1

    if test -e ${srcdir}/.gitreview; then
	local review=${srcdir}/.gitreview
    else
	if test -e ${HOME}/.gitreview; then
	    local review=${HOME}/.gitreview
	else
	    error "No ${srcdir}/.gitreview file!"
	    return 1
	fi
    fi
    
    gerrit_host="`grep host= ${review} | cut -d '=' -f 2`"
    echo ${gerrit_host}
}

extract_gerrit_project()
{
    local srcdir=$1
    if test -e ${srcdir}/.gitreview; then
	local review=${srcdir}/.gitreview
    else
	if test -e ${HOME}/.gitreview; then
	    local review=${HOME}/.gitreview
	else
	    error "No ${srcdir}/.gitreview file!"
	    return 1
	fi
    fi
    
    gerrit_project="`grep "project=" ${review} | cut -d '=' -f 2`"
    echo ${gerrit_project}
}

extract_gerrit_username()
{
    local srcdir=$1
    if test -e ${srcdir}/.gitreview; then
	local review=${srcdir}/.gitreview
	gerrit_username="`grep "username=" ${review} | cut -d '=' -f 2`"
    fi
    if test x"${gerrit_username}" = x; then
	if test -e ${HOME}/.gitreview; then
	    local review=${HOME}/.gitreview
	    gerrit_username="`grep "username=" ${review} | cut -d '=' -f 2`"
	else
	    error "No ${srcdir}/.gitreview file!"
	    return 1
	fi
    fi
    
    echo ${gerrit_username}
}

extract_gerrit_port()
{
    local srcdir=$1
    if test -e ${srcdir}/.gitreview; then
	local review=${srcdir}/.gitreview
	gerrit_port="`grep "port=" ${review} | cut -d '=' -f 2`"
    fi
    if test x"${gerrit_port}" = x; then
	if test -e ${HOME}/.gitreview; then
	    local review=${HOME}/.gitreview
	    gerrit_port="`grep "port=" ${review} | cut -d '=' -f 2`"
	else
	    error "No ${srcdir}/.gitreview file!"
	    return 1
	fi
    fi
    
    echo ${gerrit_port}
}

add_gerrit_comment ()
{
    trace "$*"

    local revision="$1"
    local message="`cat $2`"
    local code="${3:-0}"

    notice "ssh -p ${gerrit_port} ${gerrit_host} gerrit review --code-review ${code} --message \"${message}\" ${revision}"
}

submit_gerrit()
{
    local message="`cat $1`"
    local code="${2:-0}"
    local revision="${3:-}"
    notice "ssh -p ${gerrit_port} ${gerrit_host} gerrit review --code-review ${code}  --message \"${message}\" --submit ${revision}"
}

# $1 - the version of the toolname
# $2 - the build status, 0 success, 1 failure, 2 no regressions, 3 regressions
# $3 - the file of test results, if any
gerrit_build_status()
{
    trace "$*"

    local srcdir="`get_srcdir $1`"
    local status="$2"
    local resultsfile="${3:-}"
    local revision="`get_git_revision ${srcdir}`"
    local msgfile="/tmp/notify$$.txt"
    local code="0"

    declare -a statusmsg=("Build was Successful" "Build Failed!" "No Test Failures" "Found Test Failures" "No Regressions found" "Found regressions")

    cat<<EOF > ${msgfile}
Your patch is being reviewed. The build step has completed with a status
of: ${statusmsg[${status}]}
 
EOF

    if test x"${resultsfile}" != x; then
	cat ${resultsfile} >> ${msgfile}
    fi

#http://cbuild.validation.linaro.org/logs/gcc-linaro-5.0.0/

    add_gerrit_comment ${revision} ${msgfile} ${code}
    if test $? -gt 0; then
	error "Couldn't add Gerrit comment!"
	rm -f  ${msgfile}
	return 1
    fi
    rm -f  ${msgfile}
}