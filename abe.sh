#!/bin/bash
# 
#   Copyright (C) 2013, 2014, 2015, 2016 Linaro, Inc
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

usage()
{
    # Format this section with 75 columns.
    cat << EOF
  ${abe} [''| [--build {<package> [--stage {1|2}]|all}]
             [--ccache] [--check {all|glibc|gcc|gdb|binutils}]
             [--checkout {<package>[~branch][@revision]|all}]
             [--disable {bootstrap|building|install|make_docs|schroot_test|update}]
             [--dryrun] [--dump]
             [--enable {bootstrap|building|install|make_docs|schroot_test|update}]
             [--excludecheck {all|glibc|gcc|gdb|binutils}]
             [--extraconfig <tool>=<path>] [--extraconfigdir <dir>]
             [--force] [--help] [--host <host_triple>]
             [--infrastructure] [--interactive]
             [--manifest <manifest_file>]
             [--space <space needed>]
             [--parallel] [--release <release_version_string>]
             [--set {arch|cpu|tune}=XXX]
             [--set {cflags|ldflags|runtestflags|makeflags}=XXX]
             [--set {languages}={c|c++|fortran|go|lto|objc|java|ada}]
             [--set {libc}={glibc|eglibc|newlib}]
             [--set {linker}={ld|gold}]
             [--set {packages}={toolchain|gdb|sysroot}]
             [--snapshots <path>] [--tarball] [--tarbin] [--tarsrc]
             [--target {<target_triple>|''}]
             [--testcontainer user@ipaddress:ssh_port]
             [--timeout <timeout_value>]
             [--usage]
             [{binutils|dejagnu|gcc|gmp|mpfr|mpc|eglibc|glibc|newlib}
               =<id|snapshot|url>]]

EOF
    return 0
}

help()
{
    # Format this section with 75 columns.
    cat << EOF
NAME

  ${abe} - the Linaro Toolchain Build Framework.

SYNOPSIS

EOF
    usage
    cat << EOF
KEY

  [--foo]         Optional switch
  [<foo>]         Optional user specified field
  <foo>           Non-optional user specified field
  {foo|bar|bat}   Non-optional choice field
  [{foo|bar|bat}] Optional choice field
  [foo]           Optional field
  ['']            Optional Empty field
  <>              Indicates when no directive is specified

DESCRIPTION

  ${abe} is a toolchain build framework. The primary purpose of
  ${abe} is to unify the method used to build cross, native, and
  Canadian-cross GNU toolchains.

PRECONDITIONS

  Autoconf (configure) must be run in order to construct the build
  directory and host.conf file before it is valid to run ${abe}.

OPTIONS

  ''		Specifying no options will display synopsis information.

  --build {<package>|all}

                <package>
                        To build a package version that corresponds to an
                        identifier in sources.conf do --build <sources.conf
                        identifier>, e.g., --build gcc.git.

                        To build a package version that corresponds to a
                        snapshot archive do --build <snapshot fragment>,
                        e.g., --build gcc-linaro-4.7-2014.01.

                        NOTE: to build GCC stage1 or stage2 use the --stage
                        flag, as described below, along with --build gcc,
                        e.g. --build gcc --stage 2.

                all
                        Build the entire toolchain and populate the
                        sysroot.

  --ccache	Use ccache when building packages.

  --check {all|glibc|gcc|gdb|binutils}

                For cross builds this will run package unit-tests on native
                hardware

                glibc|gcc|gdb|binutils
                        Run make check on the specified package only.
                all
                        Run make check on all supported packages.

                <>
                        --check requires an input directive.
                        Calling --check without a directive is an
                        error that will cause ${abe} to abort.

  --checkout {<package>[~branch][@revision]|all}

               <package>[~branch][@revision]
                       This will checkout the package designated by the
                       <package> source.conf identifier with an optional
                       branch and/or revision designation.

               all
                       This will checkout all of the sources for a
                       complete build as specified by the config/ .conf
                       files.

  --disable {install|update|make_docs|building}

		install
                        Disable the make install stage of packages, which
                        is enabled by default.

		update
			Don't update source repositories before building.

                make_docs
                        Don't make the toolchain package documentation.

                building
                        Don't build anything. This is only useful when
                        using --tarbin, --tarsrc, or --tarball.
                        This is a debugging aid for developers, as it
                        assumes everything built correctly...
                        
  --dryrun	Run as much of ${abe} as possible without doing any
		actual configuration, building, or installing.

  --dump	Dump configuration file information for this build.

  --enable bootstrap

                Enable gcc bootstrapping, which is disabled by default.

  --excludecheck {all|glibc|gcc|gdb|binutils}

                {glibc|gcc|gdb|binutils}
                        When used with --check this will remove the
                        specified package from having its unit-tests
                        executed during make check.  When used without
                        --check this will do nothing.

                all
                        When 'all' is specified no unit tests will be run
                        regardless of what was specified with --check.

                <>
                        --excludecheck requires an input directive.
                        Calling --excludecheck without a directive is an
                        error that will cause ${abe} to abort.

                Note: This may be called several times and all valid
                packages will be removed from the list of packages to have
                unit-test executed against, e.g., the following will only
                leave glibc and gcc to have unit-tests executed:

                --check all --excludecheck gdb --excludecheck binutils

                Note: All --excludecheck packages are processed after all
                --check packages, e.g., the following will NOT check gdb:

                --check gdb --excludecheck gdb --check gdb

  --extraconfig <tool>=<path>
                Use an additional configuration file for tool.

  --extraconfigdir <dir>
                Use a directory of additional configuration files.

  --force	Force download packages and force rebuild packages.

  --help|-h	Display this usage information.

  --host <host_triple>

		Set the host triple.   This represents the machine where
		the packages being built will run.  For a cross toolchain
		build this would represent where the compiler is run.

  --infrastructure Download and install the infrastructure libraries.

  --interactive Interactively select packages from the snapshots file.

  --manifest <manifest_file>

  		Source the <manifest_file> to override the default
		configuration. This is used to reproduce an identical
		toolchain build from manifest files generated by a previous
		build. 

  --space <space_needed>

		Specify how much space (in KB) to check for in the build
		area.
		Defaults to enough space to bootstrap full toolchain.
		Set to 0 to skip the space check.

  --parallel	Set the make flags for parallel builds.

  --release <release_version_string>

                The build system will package the resulting toolchain as a
                release with the <release_version_string> embedded, e.g., if
                <release_version_string> is "2014.10-1" the GCC 4.9 tarball
                that is released will be named:

                    gcc-linaro-4.9-2014.10-1.tar.xz

  --set		{arch|cpu|tune}=XXX

		This overrides the default values used for the configure
		options --with-arch, --with-cpu, and --with-tune.

		For most targets, specifying --set cpu is equivalent to
		specifying both --set arch and --set tune, and hence those
		options should not be used with --set cpu.

		Note: There is no cross-checking to make sure that the passed
		--target value is compatible with the passed arch, cpu, or
		tune value.

  --set		{cflags|ldflags|runtestflags|makeflags}=XXX
                This overrides the default values used for CFLAGS,
                LDFLAGS, RUNTESTFLAGS, and MAKEFLAGS.

  --set		{languages}={c|c++|fortran|go|lto|objc|java|ada}
                This changes the default set of GCC front ends that get built.
                The default set for most platforms is c, c++, go, fortran,
                and lto.

  --set		{libc}={glibc|eglibc|newlib}

		The default value is stored in lib/global.sh.  This
		setting overrides the default.  Specifying a libc
		other than newlib on baremetal targets is an error.

  --set		{linker}={ld|gold}

                The default is to build the older GNU linker. This option
                changes the linker to Gold, which is required for some C++
                projects, including Andriod and Chromium.
 
  --set		{package}={toolchain|gdb|sysroot}
                This limits the default set of packages to the specified set.
                This only applies to the --tarbin, --tarsrc, and --tarballs
                command lines options, and are primarily to be only used by
                developers.

  --snapshots <path>
  		Use an alternative path to a local snapshots directory. 

  --stage {1|2}
                If --build <*gcc*> is passed, then --stage {1|2} will cause
                stage1 or stage2 of gcc to be built.  If --build <*gcc*> is
                not passed then --stage {1|2} does nothing.

  --tarball
  		Build source and binary tarballs after a successful build.

  --tarbin
  		Build binary tarballs after a successful build.

  --tarsrc
  		Build source tarballs after a successful build.

  --target	{<target_triple>|''}

		This sets the target triple.  The GNU target triple
		represents where the binaries built by the toolchain will
		execute.

		''
			Build the toolchain native to the hardware that
			${abe} is running on.
                 
		<target_triple>

			x86_64-linux-gnu
			arm-linux-gnueabi
			arm-linux-gnueabihf
			arm-none-eabi
			armeb-none-eabi
			armeb-linux-gnueabihf
			aarch64-linux-gnu
			aarch64-none-elf
			aarch64_be-none-elf
			aarch64_be-linux-gnu

			If <target_triple> is not the same as the hardware
			that ${abe} is running on then build the
			toolchain as a cross toolchain.

  --testcontainer <user>@<ipaddress>:<ssh_port>

		Specify container to use for running cross-tests for
		supported configurations.  The container should be
		configured to allow passwordless ssh on port <ssh_port>
		for <user> and "root" users.

  --timeout <timeout_value>

                Use <timeout_value> as the timeout value for wget when
                fetching snapshot packages.

  --usage	Display synopsis information.

   [{binutils|dejagnu|gcc|gmp|mpfr|mpc|eglibc|glibc|newlib}=<id|snapshot|url>]

		This option specifies a particular version of a package
		that might differ from the default version in the
		package config files. This is taken into account if the
		package is required during the build, otherwise this
		option has not effect.

		For a specific package use a version tag that matches a
		setting in a sources.conf file, a snapshots identifier,
		or a direct repository URL.

		Examples:

			# Matches an identifier in sources.conf:
			glibc=glibc.git

			# Matches a tar snapshot in md5sums:
			glibc=eglibc-linaro-2.17-2013.07

			# Direct URL:
			glibc=git://sourceware.org/git/glibc.git

EXAMPLES

  Build a Linux cross toolchain:

    ${abe} --target arm-linux-gnueabihf --build all

  Build a Linux cross toolchain with glibc as the clibrary:

    ${abe} --target arm-linux-gnueabihf --set libc=glibc --build all

  Build a bare metal toolchain:

    ${abe} --target aarch64-none-elf --build all

PRECONDITION FILES

  ~/.aberc		${abe} user specific configuration file

  host.conf		Generated by configure from host.conf.in.

ABE GENERATED FILES AND DIRECTORIES

  builds/		All builds are stored here.

  snapshots/		Package sources are stored here.

  snapshots/infrastructure Infrastructure (non-distributed) sources are stored
			here.

  snapshots/md5sums	The snapshots file of maintained package tarballs.

AUTHOR
  Rob Savoye <rob.savoye@linaro.org>
  Ryan S. Arnold <ryan.arnold@linaro.org>

EOF
    return 0
}

# If there are no command options output the usage message.
if test $# -lt 1; then
    echo "Usage:"
    usage
    echo "Run \"${abe} --help\" for detailed usage information."
    exit 1
fi

if test "$(echo $* | grep -c -- -help)" -gt 0; then
    help
    exit 0
fi

# load the configure file produced by configure
if test -e "${PWD}/host.conf"; then
    . "${PWD}/host.conf"
else
    echo "ERROR: no host.conf file!  Did you run configure?" 1>&2
    exit 1
fi

# load commonly used functions
abe="$(which $0)"
topdir="${abe_path}"
abe="$(basename $0)"

. "${topdir}/lib/common.sh" || exit 1

# this is used to launch builds of dependant components
command_line_arguments=$*

# Initialize an entry in the data array for components
collect_data abe
if [ $? -ne 0 ]; then
    error "collect_data failed"
    build_failure
fi

#
# These functions actually do something
#

# Determine whether the clibrary setting passed as $1 is compatible with the
# designated target.
crosscheck_clibrary_target()
{
    local test_clibrary="$1"
    local test_target="$2"

    case ${test_target} in
	arm*-eabi|aarch64*-*elf|*-mingw32|powerpc*-eabi|ppc*-eabi)
	    # Bare metal targets only support newlib.
	    if test x"${test_clibrary}" != x"newlib"; then
		error "${test_target} is only compatible with newlib."
		return 1
	    fi
	    ;;
	*)
	    case ${test_clibrary} in
		glibc|eglibc|newlib)
		    ;;
		*)
		    error "Invalid clibrary ${test_clibrary}."
		    return 1
		    ;;
	    esac
	    ;;
    esac
    return 0
}

select_clibrary()
{
    # Range check user input against supported C libraries.
    case "${clibrary}" in
	glibc|eglibc|newlib)
	    notice "Using '${clibrary}' as the C library as directed by \"--set libc=${clibrary}\"."
	    ;;
	auto)
	    # Certain targets only make sense using newlib as the default
	    # clibrary. Override the normal default in lib/global.sh. The
	    # user might try to override this with --set libc={glibc|eglibc}
	    # or {glibc|eglibc}=<foo> but that will be caught elsewhere.
	    case ${target} in
		arm*-eabi*|arm*-elf|aarch64*-*elf|*-mingw32|powerpc*-eabi|ppc*-eabi)
		    clibrary="newlib"
		    ;;
		*)
		    # we should use eglibc or glibc, depending on the selected
		    # configuration
		    local this_extraconfig
		    local preferred_libc
		    # get default preferred libc
		    . ${topdir}/config/preferred_libc.conf
		    # look for preferred libc in extraconfigs
		    for this_extraconfig in ${extraconfig[preferred_libc]}; do
			if test -f "${this_extraconfig}"; then
			    notice "Sourcing extra config: ${this_extraconfig}"
			    . "${this_extraconfig}"
			else
			    error "extraconfig file does not exist: ${this_extraconfig}"
			    return 1
			fi
		    done
		    if [ x"$preferred_libc" != x"" ]; then
			clibrary=$preferred_libc
		    else
			error "could not find preferred libc"
			return 1
		    fi
		    ;;
	    esac

	    ;;
	*)
	    error "'${clibrary}' is an unsupported libc option."
	    return 1
	    ;;
    esac

    # Verify that the user specified libc is compatible with
    # the user specified target.
    crosscheck_clibrary_target ${clibrary} ${target}
    if test $? -gt 0; then
	return 1
    fi
    return 0
}


# Returns '0' if $package ($1) is in the list of all_unit_tests.  Returns '1'
# if not found.
crosscheck_unit_test()
{
    local package="$1"

    # 'all' is an acceptable equivalent to the full string of packages.
    if test x"${package}" = x"all"; then
	return 0
    fi

    # We have to search for exact matches.  We don't want to match on 'gd' or
    # 'g', but rather 'gdb' and 'gcc' or the results will be unpredictable.
    for i in ${all_unit_tests}; do
        if test x"$i" = x"${package}"; then
            return 0
	fi
    done

    return 1
}

set_package()
{
    local package="$(echo $1 | cut -d '=' -f 1)"
    local setting="$(echo $* | cut -d '=' -f 2-)"

    case ${package} in
	languages)
	    with_languages="${setting}"
	    notice "Setting list of languages to build to ${setting}"
	    return 0
	    ;;
	packages)
	    with_packages="${setting}"
	    notice "Setting list of packages to build to ${setting}"
	    return 0
	    ;;
	runtestflags)
	    override_runtestflags="${setting}"
	    notice "Overriding ${setting} to RUNTESTFLAGS"
	    return 0
	    ;;
	makeflags)
#	    override_makeflags="${setting}"
	    make_flags="${make_flags} ${setting}"
	    notice "Overriding ${setting} to MAKEFLAGS"
	    return 0
	    ;;
	ldflags)
	    override_ldflags="${setting}"
	    notice "Overriding ${setting} to LDFLAGS"
	    return 0
	    ;;
	linker)
	    override_linker="${setting}"
	    notice "Overriding the default linker to ${setting}"
	    return 0
	    ;;
	cflags)
	    override_cflags="${setting}"
	    notice "Overriding ${setting} to CFLAGS"
	    return 0
	    ;;
	libc)
	    # validation is done after option parsing is complete.
	    clibrary="${setting}"
	    return 0
	    ;;
	arch)
	    override_arch="${setting}"
	    notice "Overriding default --with-arch to ${setting}"
	    return 0
	    ;;
	cpu)
	    override_cpu="${setting}"
	    notice "Overriding default --with-cpu to ${setting}"
	    return 0
	    ;;
	tune)
	    override_tune="${setting}"
	    notice "Overriding default --with-tune to ${setting}"
	    return 0
	    ;;
	*)
	    error "'${package}' is not a supported package for --set."
	    ;;
    esac

    return 1
}

# Switches that require a following directive need to make sure they don't
# parse the -- of the following switch.
check_directive()
{
    local long="$1"
    local directive="$2"

    if test x"$directive" = x; then
	error "--${long} requires a directive.  See --usage for details."
    elif test $(echo ${directive} | egrep -c "^\-+") -gt 0; then
	error "--${long} requires a directive.  ${abe} found the next -- switch.  See --usage for details."
    else
	return 0
    fi
    build_failure
}

# Some switches allow an optional following directive. We need to make sure
# they don't parse the -- of the following switch.  If there isnt a following
# directive this function will echo the default ($5).  This function can't
# distinguish whether --foo--bar is valid, so it will return 1 in this case
# and consume the --bar as part of --foo.
#
# Return Value(s):
#	stdout - caller provided directive or default
#	0 - if $directive is provided by caller
#	1 - if $directive is not provided by caller
#	exit - Execution will abort if the input is invalid.
check_optional_directive()
{
    local long="$1"
    local directive="$2"
    local default="$3"

    if test x"$directive" = x; then
	notice "There is no directive accompanying this switch.  Using --$long $default."
	directive="$default"
	echo "$directive"
	return 1
    elif test $(echo ${directive} | egrep -c "^\-+") -gt 0; then
	notice "There is no directive accompanying this switch.  Using --$long $default."
	directive="$default"
	echo "$directive"
	return 1
    fi
    echo "$directive"
    return 0
}

# Get some info on the build system
# $1 - If specified, it's the hostname of the remote system
get_build_machine_info()
{
    if test x"$1" = x; then
	cpus="$(getconf _NPROCESSORS_ONLN)"
	libc="$(getconf GNU_LIBC_VERSION)"
	kernel="$(uname -r)"
	build_arch="$(uname -p)"
	hostname="$(uname -n)"
	distribution="$(lsb_release -sc)"
    else
	# FIXME: this assumes the user has their ssh keys setup to the point
	# where the don't need a password but is secure.
	echo "Getting config info from $1"
	cpus="$(ssh $1 getconf _NPROCESSORS_ONLN)"
	libc="$(ssh $1 getconf GNU_LIBC_VERSION)"
	kernel="$(ssh $1 uname -r)"
	build_arch="$(ssh $1 uname -p)"
	hostname="$(ssh $1 uname -n)"
	distribution="$(ssh $1 lsb_release -sc)"	
    fi
}

# Takes no arguments. Dumps all the important config data
dump()
{
    # These variables are always determined dynamically at run time
    echo "Target is:         ${target}"
    echo "GCC is:            ${gcc}"
    echo "GCC version:       ${gcc_version}"
    echo "Sysroot is:        ${sysroots}"
    echo "C library is:      ${clibrary}"

    # These variables have default values which we don't care about
    echo "Binutils is:       ${binutils}"
    echo "Config file is:    ${configfile}"
    echo "Snapshot URL is:   ${local_snapshots}"

    echo "Build # cpus is:   ${cpus}"
    echo "Kernel:            ${kernel}"
    echo "Build Arch:        ${build_arch}"
    echo "Hostname:          ${hostname}"
    echo "Distribution:      ${distribution}"

    echo "Bootstrap          ${bootstrap}"
    echo "Install            ${install}"
    echo "Source Update      ${supdate}"
    echo "Make Documentation ${make_docs}"

    if test x"${release}" != x; then
        echo "Release Name       ${release}"
    fi

    if test x"${do_makecheck}" = x"all"; then
        echo "check              ${do_makecheck} {$all_unit_tests}"
    elif test ! -z "${do_makecheck}"; then
        echo "check              ${do_makecheck}"
    fi

    if test x"${do_excludecheck}" != x; then
        echo "excludecheck       ${do_excludecheck}"
    fi

    local check_components="$(get_check_component_list)"
    if test x"${check_components}" != x; then
        echo "checking           ${check_components}"
    else
        echo "checking           {none}"
    fi
}

export PATH="${local_builds}/destdir/${build}/bin:$PATH"

# do_ switches are commands that should be executed after processing all
# other switches.
do_dump=
do_checkout=
do_makecheck=
do_excludecheck=
do_build=
do_build_stage=stage2
do_manifest=""
component_version_set=""

declare -A extraconfig

# Process the multiple command line arguments
while test $# -gt 0; do
    # Get a URL for the source code for this toolchain component. The
    # URL can be either for a source tarball, or a checkout via svn, bzr,
    # or git
    case "$1" in
        --fileserver)
            warning "The --fileserver option has been removed, so ignoring it."
	    continue
	    ;;
	--build)
	    check_directive build $2
   
	    # Save and process this after all other elements have been processed.
	    do_build="$2"

	    # Shift off the 'all' or the package identifier.
	    shift
	    ;;
	--checkout)
	    check_directive checkout $2
	    # Save and process this after all other elements have been processed.
	    do_checkout="$2"

	    # Shift off the 'all' or the package identifier.
	    shift
	    ;;
	--check)
	    check_directive check $2

	    crosscheck_unit_test $2
	    ret=$?
	    if test $ret -eq 1; then
		error "${2} is an invalid package name to pass to --check. The choices are {all $all_unit_tests}."
		build_failure
	    fi

	    # Accumulate --check packages from consecutive --check calls.  Yes
	    # there might be potential duplicates but we'll prune those later.
	    # parse later.
	    do_makecheck="${do_makecheck:+${do_makecheck} }${2}"

	    shift
	    ;;
	# This will exclude an individual package from the list of packages
	# to run make check (unit-test) against.
        --excludecheck)
	    check_directive excludecheck $2

	    # Verify that $2 is a valid option to exclude.
	    crosscheck_unit_test $2
	    if test $? -eq 1; then
		error "${2} is an invalid package name to pass to --excludecheck. The choices are {all $all_unit_tests}."
		build_failure
	    fi

	    # Concatenate this onto the list of packages to exclude from make check.
            do_excludecheck="${do_excludecheck:+${do_excludecheck} }$2"

	    shift
	    ;;
	--extraconfig)
	    check_directive extraconfig $2
	    extraconfig_tool="$(echo $2 | cut -d '=' -f 1)"
	    extraconfig_val="$(echo $2 | cut -d '=' -f 2)"
	    if [ x"$extraconfig_val" != x"" ]; then
		extraconfig[${extraconfig_tool}]="${extraconfig[${extraconfig_tool}]} ${extraconfig_val}"
	    else
		# Reset extraconfig for this component
		extraconfig[${extraconfig_tool}]=""
	    fi
	    shift
            ;;
	--extraconfigdir)
	    check_directive extraconfigdir $2
	    if ! [ -d $2 ]; then
		error "Parameter for --extraconfigdir $2 is not a directory."
		build_failure
	    fi
	    for i in $(ls $2 | grep "\.conf\$"); do
		extraconfig_tool="$(basename $i .conf)"
		extraconfig_val="$2/$i"
		extraconfig[${extraconfig_tool}]="${extraconfig[${extraconfig_tool}]} ${extraconfig_val}"
	    done
	    shift
	    ;;
	--host)
	    host=$2
	    shift
	    ;;
	--manifest)
	    check_directive manifest $2
	    do_manifest=$2
	    shift
	    ;;
	# download and install the infrastructure libraries GCC depends on
	--infrastructure)
	    infrastructure
	    ;;
	--ccache)
            use_ccache=yes
            ;;
	--dryrun)
            dryrun=yes
            ;;
	--dump)
	    do_dump=yes
            #dump ${url}
	    #shift
            ;;
	--force)
	    force=yes
	    ;;
	--interactive)
	    interactive=yes
	    ;;
	--parallel)
	    parallel=yes
            ;;
	--release)
	    check_directive release $2
            release=$2
	    shift
            ;;
	--set)
	    check_directive set "$2"

	    # Test if --target follows the --set command put --set and it's
	    # directive on to the back of the inputs.  This is because clibrary
	    # validity depends on the target.
	    if test "$(echo $@ | grep -c "\-targ.*")" -gt 0; then
		# Push $1 and $2 onto the back of the inputs for later processing.
		set -- "$@" "$1" "$2"
		# Shift off them off the front.
		shift 2;
		continue;
	    fi

	    set_package $2
	    if test $? -gt 0; then
		# The failure particular reason is output within the
		# set_package function.
		build_failure
	    fi
	    shift
	    ;;
	--snapshots)
	    check_directive snapshots $2
            local_snapshots=$2
	    shift
            ;;
	--space)
	    check_directive space $2
	    space_needed=$2
	    shift
	    ;;
	--stage)
	    check_directive stage $2
	    if test x"$2" != x"2" -a x"$2" != x"1"; then
		error "--stage requires a 2 or 1 directive."
		build_failure
	    fi
	    do_build_stage="stage$2"
	    shift
	    ;;
	--tarball)
	    tarsrc=yes
	    tarbin=yes
	    ;;
	--tarbin)
	    tarbin=yes
	    ;;
	--tarsrc)
	    tarsrc=yes
	    ;;
	--target)
            target_set=1
	    check_directive target $2

	    target=$2
	    sysroots=${sysroots}/${target}

	    shift
            ;;
	--testcode)
	    testcode
	    ;;
	--testcontainer)
	    check_directive testcontainer testcontainer $2
	    test_container=$2
	    shift
	    # We need to use environment variable to communicate to dejagnu's
	    # config/linaro.exp to select the board made for container testing.
	    export ABE_TEST_CONTAINER="$test_container"
	    ;;
	--timeout)
	    check_directive timeout $2
	    tmptime="$(echo $2 | grep -o "[0-9]*")"
	    if test x"${tmptime}" != x; then
		wget_timeout=${tmptime}
	    fi
            shift
            ;;
	# These steps are disabled by default but are sometimes useful.
	--enable|--disable)
	    case "$1" in
		--enable)
		    check_directive enable $2
		    value="yes"
		    ;;
		--disable)
		    check_directive disable $2
		    value="no"
		    ;;
		*)
		    error "Internal failure.  Should never happen."
		    build_failure
		    ;;
	    esac

	    case $2 in
		bootstrap)
		    bootstrap="${value}"
		    ;;
		building)
		    building="${value}"
		    ;;
		install)
		    install="${value}"
		    ;;
		make_docs)
		    make_docs="${value}"
		    ;;
		schroot_test)
		    schroot_test="${value}"
		    ;;
		update)
		    supdate="${value}"
		    ;;
		*)
		    error "$2 not recognized as a valid $1 directive."
		    build_failure
		    ;;
	    esac
	    shift
	    ;;
	--help|-h|--h)
	    help 
	    exit 0
	     ;;
	--usage)
	    echo "Usage:"
	    usage
	    echo "Run \"${abe} --help\" for detailed usage information."
	    exit 0
	    ;;
	*)
	    # Look for unsupported -<foo> or --<foo> directives.
	    if test $(echo $1 | grep -Ec "^-+") -gt 0; then
		error "${1}: Directive not supported.  See ${abe} --help for supported options."
		build_failure
	    fi

	    # Test for <foo>= specifiers
	    if test $(echo $1 | grep -c =) -gt 0; then
		component_version_set=1
		name="$(echo $1 | cut -d '=' -f 1)"
		value="$(echo $1 | cut -d '=' -f 2)"
		case ${name} in
		    binutils)
			binutils_version="$(echo ${value})"
			;;
		    dejagnu)
			dejagnu_version="${value}"
			;;
		    gcc)
			gcc_version="${value}"
			;;
		    gmp)
			gmp_version="${value}"
			;;
		    gdb)
			gdb_version="${value}"
			;;
		    mpfr)
			mpfr_version="${value}"
			;;
                    linux)
			linux_version="${value}"
			;;
		    mpc)
			mpc_version="${value}"
			;;
		    eglibc|glibc|newlib)
			# Test if --target follows one of these clibrary set
			# commands.  If so, put $1 onto the back of the inputs.
			# This is because clibrary validity depends on the target.
			if test "$(echo $@ | grep -c "\-targ.*")" -gt 0; then
			    # Push $1 onto the back of the inputs for later processing.
			    set -- $@ $1
			    # Shift it off the front.
			    shift
			    continue;
			fi

			# Only allow valid combinations of target and clibrary.

			# Continue to process individually.
			case ${name} in
			    eglibc)
				eglibc_version="${value}"
				;;
			    glibc)
				glibc_version="${value}"
				;;
			    newlib)
				newlib_version="${value}"
				;;
			    *)
				error "FIXME: Execution should never reach this point."
				build_failure
				;;
			esac
			;;
		    *)
			# This will catch unsupported component specifiers like <foo>=
			error "${name}: Component specified not supported.  See ${abe} --help for supported components."
			build_failure
			;;
		esac
	    else
		# This will catch dangling words like <foo> that don't contain
		# --<foo> and don't contain <foo>=
		error "$1: Command not recognized.  See ${abe} --help for supported options."
		build_failure
	    fi
            ;;
    esac
    if test $# -gt 0; then
	shift
    fi
done

if [ x"$tarsrc" = x"yes" ]; then
    set_build_steps tarsrc
fi

if [ x"$tarbin" = x"yes" ]; then
    set_build_steps tarbin
fi

if [ "x${target_set}" = x1 -a ! -z "${do_manifest}" ]; then
  # see https://bugs.linaro.org/show_bug.cgi?id=2059
  error "setting --target with --manifest is not supported"
  build_failure
fi

if [ "x${component_version_set}" = x1 -a ! -z "${do_manifest}" ]; then
  error "setting component versions with --manifest is not supported"
  build_failure
fi

# resolve C library from command line options, defaults, or extraconfig.
select_clibrary
if [ $? -ne 0 ]; then
    error "Failed to resolve C library choice."
    build_failure
fi

if [ ! -z "${do_manifest}" ]; then
    import_manifest "$do_manifest"
    if test $? -gt 0; then
        build_failure
    fi
fi

# Check disk space. Each builds needs about 3.8G free
if test x"${space_needed}" = x; then
  space_needed=4194304
fi
if test ${space_needed} -gt 0; then
  df="$(df ${abe_top} | tail -1 | tr -s ' ' | cut -d ' ' -f 4)"
  if test ${df} -lt ${space_needed}; then
      error "Not enough disk space!"
      exit 1
  fi
fi

# if test x"${tarbin}" = x"yes" -o x"${tarsrc}" = x"yes"; then
#     warning "No testsuite will be run when building tarballs!"
#     runtests=no
# fi

if test x"${force}" = xyes -a x"$supdate" = xno; then
    warning "You have specified \"--force\" and \"--disable update\"."
    echo "         Using \"--force\" overrides \"--disable update\".  Sources will be redownloaded."
fi

if test ! -z "${do_makecheck}"; then
    # If we encounter 'all' in ${do_makecheck} anywhere we just overwrite
    # runtests with ${all_unit_tests} and ignore the rest.
    test_all="${do_makecheck//all/}"

    if test x"${test_all}" != x"${do_makecheck}"; then
	runtests="${all_unit_tests}"
    else
	# Don't accumulate any duplicates.
        for i in ${do_makecheck}; do
	    # Remove it if it's already there
	    runtests=${runtests//${i}/}
	    # Remove any redundant whitespace
	    runtests=${runtests//  /}
	    # Reinsert it if it was already in the list.
            runtests="${runtests:+${runtests} }${i}"
        done
    fi
fi

if test ! -z "${do_excludecheck}"; then

    # If we encounter 'all' in ${do_excludecheck} anywhere we just
    # empty out runtests because 'all' trumps everything.
    exclude_all="${do_excludecheck//all/}"
    if test x"${exclude_all}" != x"${do_excludecheck}"; then
        runtests=
    else
	#Remove excluded packages (stored in do_excludecheck) from ${runtests}
	for i in ${do_excludecheck}; do
	    runtests="${runtests//$i/}"
	    # Strip redundant white spaces
	    runtests="${runtests//  / }"
	done
	# Strip white space from the beginning of the string
	runtests=${runtests# }
	# Strip white space from the end of the string
	runtests=${runtests% }
    fi
fi

if [ ! -z "${runtests}" ]; then
    set_check_component_list "${runtests}"
    set_build_steps check
fi

# Process 'dump' after we process 'check' and 'excludecheck' so that the list
# of tests to be evaluated is resolved before the dump.
if test ! -z ${do_dump}; then
    dump
fi

# Both checkout and build need the build dir.  'build' uses it for the builds.
# It's not clear whether 'checkout' still uses it.
if test ! -z "${do_checkout}" -o ! -z "${do_build}"; then
    # Sometimes a user might remove ${local_builds} to restart the build.
    if test ! -d "${local_builds}"; then
	warning "${local_builds} does not exist. Recreating build directory!"
	mkdir -p ${local_builds}
    fi
fi

if test ! -z ${do_checkout}; then
    if test x"${do_checkout}" != x"all"; then
        set_build_component_list "${do_checkout}"
    else
	set_build_component_list "$(get_component_list)"
    fi
    set_build_steps checkout
fi

if test ! -z ${do_build}; then
    if test x"${do_build}" != x"all"; then
	gitinfo="${do_build}"
	if test x"${gitinfo}" = x; then
	    error "Couldn't find the source for ${do_build}"
	    build_failure
	else
	    build_param=
	    # If we're just building gcc then we need to pick a 'stage'.
	    # The user might have specified a stage so we use that if
	    # it's set.
	    if test $(echo ${do_build} | grep -c "gcc") -gt 0; then
	        set_build_component_list "${do_build_stage}"
	    else
		set_build_component_list "${gitinfo}"
	    fi
	fi
    else
	set_build_component_list "$(get_component_list)"
    fi	 
    set_build_steps build
fi

perform_build_steps
if test $? -ne 0; then
    build_failure
fi

time="$(expr ${SECONDS} / 60)"
if test ! -z ${do_build}; then
    notice "Complete build process took ${time} minutes"
elif test ! -z ${do_checkout}; then
    notice "Complete checkout process took ${time} minutes"
fi

if [ ! -z "$ERROR_DETECTED" ]; then
    error "Unhandled error occurred during build."
    exit 1
fi
exit 0
