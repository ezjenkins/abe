#!/bin/sh

# Configure a source directory
# $1 - the directory to configure
# $2 - which gcc stage to build
configure_build()
{
    builddir=`get_builddir $1`    
    dir="`normalize_path $1`"
    if test `echo $1 | grep -c trunk` -gt 0; then
	srcdir="${local_snapshots}/${dir}/trunk"
    else
	srcdir="${local_snapshots}/${dir}"
    fi
    
    if test ! -d ${builddir}; then
	notice "${builddir} doesn't exist, so creating it"
	mkdir -p ${builddir}
    fi

    # not all packages commit their configure script, so if it has autogen,
    # then run that to create the configure script.
    if test ! -f ${srcdir}/configure; then
	warning "No configure script in ${srcdir}!"
	if test -f ${srcdir}/autogen.sh; then
	    (cd ${srcdir} && ./autogen.sh)
	fi
	return 0
    fi

    # If a target architecture isn't specified, then it's a native build
    if test x"${target}" = x; then
	target=${build}
	host=${build}
    fi

    # Extract the toolchain component name, stripping off the linaro
    # part if it exists as it's not used for the config file name.
    tool="`get_toolname $1 | sed -e 's:-linaro::'`"


    # Load the default config file for this component if it exists.
    default_configure_flags=""
    stage1_flags=""
    stage2_flags=""
    opts=""
    if test -e "${topdir}/config/${tool}.conf"; then
	. "${topdir}/config/${tool}.conf"
	# if there is a local config file in the build directory, allow
	# it to override the default settings
	# unset these two variables to avoid problems later
	if test -e "${builddir}/${tool}.conf"; then
#	    if test ${builddir}/${tool}.conf -nt ${topdir}/config/${tool}.conf; then
#	    fi
	    . "${builddir}/${tool}.conf"
	    notice "Local ${tool}.conf overiding defaults"
	else
	    # Since there is no local config file, make one using the
	    # default, and then add the target architecture so it doesn't
	    # have to be supplied for future reconfigures.
	    echo "target=${target}" > ${builddir}/${tool}.conf
	    cat ${topdir}/config/${tool}.conf >> ${builddir}/${tool}.conf
	fi
    fi

    # See if this component depends on other components. They then need to be
    # built first.
    if test x"${depends}"; then
	for i in "${depends}"; do
	    # remove the current build component from the command line arguments
	    # so we can replace it with the dependent component name.
	    args="`echo ${command_line_arguments} | sed -e 's@$1@@'`"
	done
    fi

    # eglibc won't produce a static library if GCC is configured to be statically.
    # A static iconv_prog wants libgcc_eh, which is only created wth a dynamically
    # build GCC.
    if test x"${tool}" != x"eglibc"; then
	opts="--disable-shared --enable-static"
    fi

    # Add all the rest of the arguments to the options used when configuring.
#    if test $# -gt 1; then
#	opts="${opts} `echo $* | cut -d ' ' -f2-10`"
#    fi

    # GCC and the binutils are the only toolchain components that need the
    # --target option set, as they generate code for the target, not the host.
    case ${tool} in
	newlib|libelf*)
	    opts="${opts} --build=${build} --host=${target} --target=${target} --prefix=${sysroots}/usr"
	    ;;
	*libc)
	    opts="${opts} --build=${build} --host=${target} --target=${target} --prefix=/usr"
	    ;;
	gcc)
	    # Force a complete reconfigure, as we changed the flags. We could do a
	    # make distclean, but this builds faster, as not all files have to be
	    # recompiled.
	    find ${builddir} -name Makefile -o -name config.cache -exec rm {} \;
	    if test x"${build}" != x"${target}"; then
		if test x"$2" != x; then
		    case $2 in
			stage1*)
			    notice "Building stage 1 of GCC"
			    opts="${opts} ${stage1_flags}"
			    ;;
			stage2*)
			    notice "Building stage 2 of GCC"
			    opts="${opts} ${stage2_flags}"
			    ;;
			bootstrap*)
			    notice "Building bootstrapped GCC"
			    opts="${opts} --enable-bootstrap"
			    ;;
			*)
			    if test -e ${sysroots}/usr/include/stdio.h; then
				notice "Building with stage 2 flags, sysroot found!"
				opts="${opts} ${stage2_flags}"
			    else
				warning "Building with stage 1 flags, no sysroot found"
				opts="${opts} ${stage2_flags}"
			    fi
			    ;;
		    esac
		else
		    if test -e ${sysroots}/usr/include/stdio.h; then
			notice "Building with stage 2 flags, sysroot found!"
			opts="${opts} ${stage2_flags}"
		    else
			warning "Building with stage 1 flags, no sysroot found"
			opts="${opts} ${stage2_flags}"
		    fi
		fi
	    else
		opts="${opts} ${stage2_flags}"
	    fi
	    version="`echo $1 | sed -e 's#[a-zA-Z\+/:@.]*-##' -e 's:\.tar.*::'`"
	    opts="${opts} --build=${build} --host=${build} --target=${target} --prefix=${local_builds}"
	    ;;
	binutils)
	    opts="${opts} --build=${build} --host=${build} --target=${target} --prefix=${local_builds}"
	    ;;
	gmp|mpc|mpfr|isl|ppl|cloog)
	    opts="${opts} --prefix=${local_builds} ${opts}"
	    ;;
	*)
    esac

    if test -e ${builddir}/config.status -a x"${force}" = x"no"; then
	warning "${buildir} already configured!"
    else
	export CONFIG_SHELL=${bash_shell}
	(cd ${builddir} && ${bash_shell} ${srcdir}/configure ${default_configure_flags} ${opts})
	return $?
	# unset this to avoid problems later
	default_configure_flags=
    fi

    return 0
}

