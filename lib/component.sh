#!/bin/bash
# 
#   Copyright (C) 2015 Linaro, Inc
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

declare -Ag toolchain

# This file attempts to turn an associative array into a semblance of a
# data structure. Note that this will only work with the bash shell.
#
# The default fields are 
# TOOL
# URL
# REVISION
# BRANCH
# SRCDIR
# BUILDDIR
# FILESPEC

# Initialize the associative array
# parameters:
#	$ - Any parameter without a '=' sign becomes the name of the the array.
#	    
component_init ()
{
    trace "$*"

    local component=
    local index=
    for index in $*; do
	if test "`echo ${index} | grep -c '='`" -gt 0; then
	    name="`echo ${index} | cut -d '=' -f 1`"
	    value="`echo ${index} | cut -d '=' -f 2`"
	    eval ${component}[${name}]="${value}"
	    if test $? -gt 0; then
		return 1
	    fi
	else
	    component="`echo ${index} | sed -e 's:-[0-9a-z\.\-]*::'`"
	    declare -Ag ${component}
	    eval ${component}[TOOL]="${component}"
	    if test $? -gt 0; then
		return 1
	    fi
	fi
    done

    return 0
}

# Accessor functions for the data structure to set "private" data. This is a crude
# approximation of an object oriented API for this data structure. Each of the setters
# takes two arguments, which are:
#
# $1 - The name of the data structure, which is based on the toolname, ie... gcc, gdb, etc...
# $2 - The value to assign the data field.
#
# Returns 0 on success, 1 on error
#
set_component_url ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[URL]="$2"
    fi

    return 0
}

set_component_revision ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[REVISION]="$2"
    fi

    return 0
}

set_component_srcdir ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[SRCDIR]="$2"
    fi

    return 0
}

set_component_builddir ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[BUILDDIR]="$2"
    fi

    return 0
}

set_component_filespec ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[FILESPEC]="$2"
    fi

    return 0
}

set_component_branch ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    declare -p ${component} 2>&1 > /dev/null
    if test $? -gt 0; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval ${component}[BRANCH]="$2"
    fi

    return 0
}

# Accessor functions for the data structure to get "private" data. This is a crude
# approximation of an object oriented API for this data structure. All of the getters
# take only one argument, which is the toolname, ie... gcc, gdb, etc...
#
# $1 - The name of the data structure, which is based on the toolname, ie... gcc, gdb, etc...
#
# Returns 0 on success, 1 on error, and the value is returned as a string.
#
get_component_url ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[URL]}"
    fi

    return 0
}

get_component_revision ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[REVISION]}"
    fi

    return 0
}

get_component_srcdir ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[SRCDIR]}"
    fi

    return 0
}

get_component_builddir ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[BUILDDIR]}"
    fi

    return 0
}

get_component_filespec ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[FILESPEC]}"
    fi

    return 0
}

get_component_branch ()
{
#    trace "$*"

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    else
	eval "echo \${${component}[BRANCH]}"
    fi

    return 0
}

# declare -p does print the same data from the array, but this is an easier to
# read version of the same data.
component_dump()
{
    trace "$*"

    local flag="`set -o | grep xtrace| tr -s ' ' | tr -d '\t' | cut -d ' ' -f 2`"
    set +x

    local component="`echo $1 | sed -e 's:-[0-9a-z\.\-]*::' -e 's:\.git.*::'`"
    if test "${component:+set}" != "set"; then
	echo "WARNING: ${component} does not exist!"
	return 1
    fi

    local data="`declare -p ${component} | sed -e 's:^.*(::' -e 's:).*$::'`"
    
    echo "Data dump of component \"${component}\""
    for i in ${data}; do
	echo "	$i"
    done

    if test x"${flag}" = x"on"; then
        set -x
    fi

    return 0
}

collect_data ()
{
    trace "$*"

    local component="`echo $1 | sed -e 's:\.git.*::' -e 's:-[0-9a-z\.\-]*::'`"
    local version="${component}_version"
    local tool="${!version}"
    if test x"${tool}" = x; then
	eval ${component}_version="`grep ^latest= ${topdir}/config/${component}.conf | cut -d '\"' -f 2`"
    fi

    if test `echo $1 | grep -c "\.tar"` -gt 0; then
	local url="`get_URL ${component}`"
	if test "`echo ${url} | grep -c infrastructure`" -gt 0; then
	    local dir="/infrastructure"
	else
	    local dir=""
	fi
	local filespec="`basename $1`"
    else
	local gitinfo="${!version}"
	local branch="`get_git_branch ${gitinfo}`"
	local search=
	case ${component} in
	    binutils*) search="binutils-gdb.git";;
	    gdb*) search="binutils-gdb.git" ;;
	    *) search="${component}\." ;;
	esac
	local url="`grep ^${search} ${sources_conf} | tr -s ' ' | cut -d ' ' -f 2`"
	if test x"{$url}" = x; then
	    warning "${component} Not found in  ${sources_conf}"
	    return 1
	fi
	local filespec="`basename ${url}`"
	local url="`dirname ${url}`"
	local revision="`get_git_revision ${gitinfo}`"
	local fixbranch="`echo ${branch} | tr '/' '~'`"
	local dir=${component}.git${branch:+~${fixbranch}}${revision:+@${revision}}
    fi

    
    local builddir="${local_builds}/${host}/${target}/${dir}"
    local srcdir="${local_snapshots}/${dir}"

    fixme "TOOL=${component} ${branch:+BRANCH=${branch}} ${revision:+REVISION=${revision}} ${srcdir:+SRCDIR=${srcdir}} ${builddir:+BUILDDIR=${builddir}} ${filespec:+FILESPEC=${filespec}} ${url:+URL=${url}}"
    component_init ${component} TOOL=${component} ${branch:+BRANCH=${branch}} ${revision:+REVISION=${revision}} ${srcdir:+SRCDIR=${srcdir}} ${builddir:+BUILDDIR=${builddir}} ${filespec:+FILESPEC=${filespec}} ${url:+URL=${url}}

    return 0
}