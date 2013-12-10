#!/bin/sh

#
# This does a checkout from a source code repository
#

# It's optional to use git-bzr-ng or git-svn to work on the remote sources,
# but we also want to work with the native source code control system.
usegit=no

# This is used by cbuild2.sh --checkout all but not by --build
checkout_infrastructure()
{
    trace "$*"

    source_config infrastructure

    if test x"${depends}" = x; then
	error "No dependencies listed for infrastructure libraries!"
	return 1
    fi

    # This shouldn't happen, but it's nice for regression verification.
    if test ! -e ${local_snapshots}/md5sums; then
	error "Missing ${local_snapshots}/md5sums file needed for infrastructure libraries."
	return 1
    fi

    # We have to grep each dependency separately to preserve the order, as
    # some libraries depend on other libraries being bult first. Egrep
    # unfortunately sorts the files, which screws up the order.
    local files="`grep ^latest= ${topdir}/config/dejagnu.conf | cut -d '\"' -f 2`"
    for i in ${depends}; do
     	files="${files} `grep /$i ${local_snapshots}/md5sums | cut -d ' ' -f3 | uniq`"
    done


    for i in ${files}; do
	local name="`echo $i | sed -e 's:\.tar\..*::' -e 's:infrastructure/::'  -e 's:testcode/::'`"
        local gitinfo=
	gitinfo="`get_source ${name}`"
	if test -z "${gitinfo}"; then
	    error "No matching source found for \"${name}\"."
	    return 1
	fi

	# Some infrastructure packages (like dejagnu) come from a git repo.
	local service=
	service="`get_git_service ${gitinfo}`"
	if test x"${service}" != x; then
	    local checkout_ret=
	    checkout ${gitinfo}
	    checkout_ret=$?
	    if test ${checkout_ret} -gt 0; then
		error "Failed checkout out of ${name}."
		return 1
	    fi
	else
	    fetch ${gitinfo}
	    if test $? -gt 0; then
		error "Couldn't fetch tarball ${gitinfo}"
		return 1
	    fi
	    extract ${gitinfo}
	    if test $? -gt 0; then
		error "Couldn't extract tarball ${gitinfo}"
		return 1
	    fi
	fi
    done
    return 0
}

# This is similar to make_all except it _just_ gathers sources trees and does
# nothing else.
checkout_all()
{
    local packages=
    packages="binutils libc gcc gdb"

    # See if specific component versions were specified at runtime
    if test x"${gcc_version}" = x; then
	gcc_version="`grep ^latest= ${topdir}/config/gcc.conf | cut -d '\"' -f 2`"
    fi
    if test x"${binutils_version}" = x; then
	binutils_version="`grep ^latest= ${topdir}/config/binutils.conf | cut -d '\"' -f 2`"
    fi
    if test x"${eglibc_version}" = x; then
	eglibc_version="`grep ^latest= ${topdir}/config/eglibc.conf | cut -d '\"' -f 2`"
    fi
    if test x"${newlib_version}" = x; then
	newlib_version="`grep ^latest= ${topdir}/config/newlib.conf | cut -d '\"' -f 2`"
    fi
    if test x"${glibc_version}" = x; then
	glibc_version="`grep ^latest= ${topdir}/config/glibc.conf | cut -d '\"' -f 2`"
    fi
    if test x"${gdb_version}" = x; then
	gdb_version="`grep ^latest= ${topdir}/config/gdb.conf | cut -d '\"' -f 2`"
    fi

    checkout_infrastructure
    if test $? -gt 0; then
	return 1
    fi

    for i in ${packages}; do
	local package=
	case $i in
	    gdb)
		package=${gdb_version}
		;;
	    binutils)
		package=${binutils_version}
		;;
	    gcc)
		package=${gcc_version}
		;;
	    libc)
		if test x"${clibrary}" = x"eglibc"; then
		    package=${eglibc_version}
		elif  test x"${clibrary}" = x"glibc"; then
		    package=${glibc_version}
		elif test x"${clibrary}" = x"newlib"; then
		    package=${newlib_version}
		else
		    error "\${clibrary}=${clibrary} not supported."
		    return 1
		fi
		;;
	    *)
		;;
	esac

    	local gitinfo="`get_source ${package}`"
	local checkout_ret=
	checkout ${gitinfo}
	checkout_ret=$?

	if test ${checkout_ret} -gt 0; then
	    error "Failed checkout out of $i."
	    return 1
	fi
    done

    notice "Checkout all took ${SECONDS} seconds"

    return 0
}


# This gets the source tree from a remote host
# $1 - This should be a service:// qualified URL.  If you just
#       have a git identifier call get_URL first.
checkout()
{
    if test x"$1" = x; then
	error "No URL given!"
	return 1
    fi

    local service=
    service="`get_git_service $1`"
    if test x"${service}" = x ; then
	error "A proper url is required. Call get_URL first."
	return 1
    fi

    local repo=
    repo="`get_git_repo $1`"

    local tool=
    tool="`get_toolname $1`"
    local url=
    url="`get_git_url $1`"
    local branch=
    branch="`get_git_branch $1`"
    local revision=
    revision="`get_git_revision $1`"

    local srcdir=
    srcdir="`get_srcdir $1`"

    case $1 in
	bzr*|lp*)
	    if test x"${force}" =  xyes; then
		#rm -fr ${local_snapshots}/${dir}
		echo "Removing existing sources for ${srcdir}"
	    fi
	    if test x"${usegit}" =  xyes; then
		local out="`git-bzr clone $1 ${srcdir}`"
	    else
		if test -e ${srcdir}/.bzr; then
		    local out="`(cd ${srcdir} && bzr pull)`"
		else
		    local out="`bzr branch $1 ${srcdir}`"
		fi
	    fi
	    ;;
	svn*)
	    local trunk="`echo $1 |grep -c trunk`"
	    if test ${trunk} -gt 0; then
		local dir="`dirname $1`"
		local dir="`basename ${dir}`/trunk"
	    fi
	    if test x"${force}" =  xyes; then
		#rm -fr ${local_snapshots}/${dir}
		echo "Removing existing sources for ${srcdir}"
	    fi
	    if test x"${usegit}" =  xyes; then
		local out="`git svn clone $1 ${srcdir}`"
	    else
		if test -e ${srcdir}/.svn; then
		    (cd ${srcdir} && svn update)
		    # Extract the revision number from the update message
		    local revision="`echo ${out} | sed -e 's:.*At revision ::' -e 's:\.::'`"
		else
		    svn checkout $1 ${srcdir}
		fi
	    fi
	    ;;
	git*|http*)
	    if test -e ${srcdir}/.git -o -e ${srcdir}/.gitignore; then
		notice "Updating sources for $1 in ${srcdir}"
		# A revision represents a snapshot in time so it doesn't need to
		# be updated.  Otherwise for a named branch or 'master' we pull.
		if test x"${revision}" = x; then
		    # If there's branch info, pull branch, otherwise just pull.
		    dryrun "(cd ${srcdir} && git pull origin${branch:+ ${branch}})"
		fi
		# NOTE: It's possible that a git-new-workdir succeeded but the
		# git checkout -b [branch|revision] didn't in which case our
		# directory would be in the 'master' branch rather than a named
		# branch but we can't handle every corner case.
	    else
		notice "Checking out sources for $1 into ${srcdir}"
		if test x"${branch}" = x -a x"${revision}" = x; then
		    dryrun "git clone $1 ${srcdir}"
		else
		    if test ! -d ${local_snapshots}/${repo}; then
			# Strip off the "[/<branchname>][@<revision>]" from $1 to
			# get the repo address
			dryrun "git clone ${url} ${local_snapshots}/${repo}"
		    fi

		    # If revision is set only use ${branch} for naming.
		    if test x"${revision}" != x; then
			notice "Creating git workdir for revision ${revision}"
			dryrun "git-new-workdir ${local_snapshots}/${repo} ${srcdir}"
			if test $? -gt 0; then
			    error "Couldn't create git workdir ${srcdir}"
			    return 1
			fi

			# Check out detached head state at ${revision}.
			dryrun "(cd ${srcdir} && git checkout ${revision})"
			if test $? -gt 0; then
			    error "Couldn't checkout ${revision}"
			    return 1
			fi
			# Create a [branch_]revision working branch.
			dryrun "(cd ${srcdir} && git checkout -b "${branch:+${branch}_}${revision}")"
		    elif test x"${branch}" != x; then
			# If there's no revision we checkout a specific branch.
			dryrun "git-new-workdir ${local_snapshots}/${repo} ${srcdir}${branch:+ ${branch}}"
		    fi
		    # We don't need a new-workdir if there's no designated
		    # branch or revision.
		fi
	    fi
	    ;;
	*)
	    ;;
    esac

    if test $? -gt 0; then
	error "Couldn't checkout $1 !"
	return 1
    fi

    return 0
}

# This pushes a source tree up to a remote host. For bzr and git, any changes
# that should be uploaded to the remote source repository need to be commit()'d
# first. For svn and cvs, this push does a commit instead.
# $1 - The URL to push to, same as used for checkout
# $2 - The optional host to push to
# $3 - The optional branch to push to
push ()
{
    if test x"$1" = x; then
	error "No URL given!"
	return 1
    fi
    if test x"$2" = x; then
	warning "No host given, so using origin"
	local repo="origin"
    fi

    # bzr uses slashes in it's path names, so convert them so we
    # can use the for accessing the source directory.
    local url="`echo $1 | sed -e 's:/:_:'`"
    local dir="`basename ${url} |sed -e 's/^.*://'`"

    # We use git for our copy by importing from the other systems
    case $1 in
	bzr*|lp*)
	    if test x"${usegit}" =  xyes; then
		#out="`git-bzr push $1 ${local_snapshots}/${dir}`"
		echo "FIXME: shouldn't be here!"
	    else
		if test -e ${local_snapshots}/${dir}/.bzr; then
		    #out="`(cd ${local_snapshots}/${dir} && bzr push)`"
		    notice "Pushing ${dir} upstream..."
		    notice "bzr push ${url}"
		else
		    error "${local_snapshots}/${dir} doesn't exist!"
		    return 1
		fi
	    fi
	    ;;
	svn*)
	    local trunk="`echo $1 |grep -c trunk`"
	    if test ${trunk} -gt 0; then
		local dir="`dirname $1`"
		local dir="`basename ${dir}`/trunk"
	    fi
	    if test x"${usegit}" =  xyes; then
		#out="`git svn push $1 ${local_snapshots}/${dir}`"
		echo "FIXME: shouldn't be here!"
	    else
		if test -e ${local_snapshots}/${dir}/.svn; then
		    #out="`(cd ${local_snapshots}/${dir} && svn commit`"
		    notice "Pushing ${dir} upstream"
		    notice "svn commit ${url}"
		else
		    error "${local_snapshots}/${dir} doesn't exist!"
		    return 1
		fi
	    fi
	    ;;
	git*)
	    if test x"$3" = x; then
		warning "No branch given, so using master or trunk"
		local branch="master"
	    fi
	    if test -e ${local_snapshots}/${dir}/.git; then
		#out="`(cd ${local_snapshots}/${dir} && git push ${repo} ${branch}`"
		notice "Pushing ${dir} upstream"
		notice "git push ${repo} ${branch}"
	    else
		error "${local_snapshots}/${dir} doesn't exist!"
		return 1
	    fi
	    ;;
	*)
	    ;;
    esac

    return 0
}

# This commits a change to a source tree. For bzr and git, this only
# modifies the local source tree, and push() must be executed to actually
# upload the changes to the remote source tree. For svn and cvs, the
# commit modifies the remote sources at the same time.
# $1 - The URL used for checkout()
# $2 - the file or directory to commit
commit ()
{
    # bzr uses slashes in it's path names, so convert them so we
    # can use the for accessing the source directory.
    local url="`echo $1 | sed -e 's:/:_:'`"
    local dir="`basename ${url} |sed -e 's/^.*://'`"

    # We use git for our copy by importing from the other systems
    case $1 in
	bzr*|lp*)
	    if test x"${usegit}" =  xyes; then
		#out="`git-bzr push $1 ${local_snapshots}/${dir}`"
		echo "FIXME: shouldn't be here!"
	    else
		if test x"$2" = x; then
		    warning "No file given, so commiting all"
		    local files=""
		else
		    local files="$2"
		fi
		if test -e ${local_snapshots}/${dir}/.bzr; then
		    #out="`(cd ${local_snapshots}/${dir} && bzr commit --file ${local_snapshots}/${dir}/commitmsg.txt ${files}`"
		    notice "Committing ${dir} to local repository..."
		    notice "bzr commit -m \"`cat ${local_snapshots}/${dir}/commitmsg.txt`\" ${files}"
		else
		    error "${local_snapshots}/${dir} doesn't exist!"
		    return 1
		fi
	    fi
	    ;;
	svn*)
	    local trunk="`echo $1 |grep -c trunk`"
	    if test ${trunk} -gt 0; then
		local dir="`dirname $1`"
		local dir="`basename ${dir}`/trunk"
	    fi
	    if test x"$2" = x; then
		warning "No file given, so commiting all"
		local files=""
	    else
		local files="$2"
	    fi
	    if test x"${usegit}" =  xyes; then
		#out="`git svn push $1 ${local_snapshots}/${dir}`"
		echo "FIXME: shouldn't be here!"
	    else
		if test -e ${local_snapshots}/${dir}/.svn; then
		    #out="`(cd ${local_snapshots}/${dir} && svn commit --file ${local_snapshots}/${dir}/commitmsg.txt ${files}`"
		    notice "Committing ${files} to remote repository"
		    notice "svn commit -m  \"`cat ${local_snapshots}/${dir}/commitmsg.txt`\" ${files}"
		else
		    error "${local_snapshots}/${dir} doesn't exist!"
		    return 1
		fi
	    fi
	    ;;
	git*)
	    if test x"$2" = x; then
		warning "No files given, so commiting all"
		local files="-a"
	    else
		local files="$2"
	    fi
	    if test -e ${local_snapshots}/${dir}/.git; then
		#out="`(cd ${local_snapshots}/${dir} && git commit --file ${local_snapshots}/${dir}/commitmsg.txt ${files}`"
		notice "Committing ${files} to local repository..."
		notice "git commit -m \"`cat ${local_snapshots}/${dir}/commitmsg.txt`\" ${files}"
   	    else
		error "${local_snapshots}/${dir} doesn't exist!"
		return 1
	    fi
	    ;;
	*)
	    ;;
    esac

    return 0
}

# Create a new tag in a repository
# $1 - The URL used for checkout()
# $2 - the tag name
tag()
{
    error "unimplemented"
}

# Change the active branch.
# FIXME: for now, this only supports git.
#
# $1 - The toolchain component to use, which looks like this:
# gcc.git/linaro-4.8-branch@123456
# Which breaks down as gcc.git is the component name. Anything after a slash
# is the branch. Anything after a '@' is a GIT commit hash ID.
change_branch()
{
    trace "$*"

    local dir="`normalize_path $1`"
    local version="`basename $1`"
    local branch="`echo $1 | cut -d '/' -f 2`"

    local srcdir="`get_srcdir $1`"
    if test "`echo $1 | grep -c '@'`" -gt 0; then
	local revision="`echo $1 | cut -d '@' -f 2`"
    else
	local revision=""
    fi

    if test ! -d ${srcdir}/${branch}; then
	dryrun "git-new-workdir ${local_snapshots}/${version} ${local_snapshots}/${version}-${branch} ${branch}"
    else
	if test x"${branch}" = x; then
	    dryrun "(cd ${local_snapshots}/${version} && git pull origin master)"
	else
	    dryrun "(cd ${local_snapshots}/${version}-${branch} && git pull origin ${branch})"
	fi
    fi
    
    return 0
}

