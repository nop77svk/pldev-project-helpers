#!/bin/bash
set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail
[ -n "${DEBUG:=}" ] && set -x # xtrace

Here="$PWD"
FullScriptPath=$( echo "$0" | sed 's/\\/\//g' | sed 's/\([a-z]\):/\/cygdrive\/\1/gi' )
ScriptPath=$( dirname "${FullScriptPath}" )
cd "${ScriptPath}"
ScriptPath="$PWD"
LibPath="${ScriptPath}/lib"
cd "${Here}"
TmpPath="${Here}"

DateTimeToken=$( date +%Y%m%d-%H%M%S )
RndToken=${DateTimeToken}-${RANDOM}

# ------------------------------------------------------------------------------------------------

function bash__VersionIsAtLeast()
{
	local bashMajorVersion=${BASH_VERSION%%.*}
	local bashMinorVersion=${BASH_VERSION#*.}
	local bashMinorVersion=${bashMinorVersion%%.*}

	local targetMajorVersion=$1
	local targetMinorVersion=$2

	[ ${bashMajorVersion} -gt ${targetMajorVersion} -o ${bashMajorVersion} -eq ${targetMajorVersion} -a ${bashMinorVersion} -ge ${targetMinorVersion} ]
}

function bash__SupportsVariableReferences()
{
	bash__VersionIsAtLeast 4 3
}

# ------------------------------------------------------------------------------------------------

function decryptProjectFile()
{
	local i_input_file=$1
	local i_output_file="$2"

	cat "${i_input_file}" \
		| dos2unix \
		| gawk -f "${LibPath}/_pldev_proj_decrypt_groups.awk" \
		> "${i_output_file}"
}

# -------------------------------------------------------------------------------------------------

# set up path to the TortoiseMerge.exe here...
TortoiseMergeBinary=tmerge.exe

# -------------------------------------------------------------------------------------------------
# read command line arguments...

function set_arg()
{
	xScriptArg="$1"
	xOptionToTest="$2"
	if bash__SupportsVariableReferences ; then
		declare -n oResult=$3
	fi

	if [[ "${xScriptArg}" == "--${xOptionToTest}="* ]] ; then
		lScriptArgWoOptionToTest="${xScriptArg#--${xOptionToTest}=}"
		if bash__SupportsVariableReferences ; then
			oResult="${lScriptArgWoOptionToTest}"
		else
			eval $3=\$lScriptArgWoOptionToTest
		fi
	else if [ "${xScriptArg}" = "--${xOptionToTest}" ] ; then
		if bash__SupportsVariableReferences ; then
			oResult="${xOptionToTest}"
		else
			eval $3=\$xOptionToTest
		fi
	else
		echo "nothing :-("
	fi ; fi
}

xModusOperandi=svn
for l_arg in "$@" ; do
	set_arg "${l_arg}" "svn" xModusOperandi
	set_arg "${l_arg}" "bzr" xModusOperandi
	set_arg "${l_arg}" "git" xModusOperandi

	set_arg "${l_arg}" "mine" xMine
	set_arg "${l_arg}" "theirs" xTheirs
	set_arg "${l_arg}" "base" xBase
	set_arg "${l_arg}" "result" xResult

	set_arg "${l_arg}" "working" xMine
	set_arg "${l_arg}" "right" xTheirs
	set_arg "${l_arg}" "left" xBase
	set_arg "${l_arg}" "merged" xResult
done

xMine="${xMine:-}"
xTheirs="${xTheirs:-}"
xResult="${xResult:-}"
xBase="${xBase:-}"

# -------------------------------------------------------------------------------------------------

if [ -z "${xTheirs}" -o -z "${xResult}" ] ; then
	echo Options:
	echo "	--theirs=<file>"
	echo "	--mine=<file>"
	echo "	--base=<file>"
	echo "	--result=<file>"
	echo "	--left=<file> ... alias for --base for SVN conflict merges"
	echo "	--right=<file> ... alias for --theirs for SVN conflict merges"
	echo "	--working=<file> ... alias for --mine for SVN conflict merges"
	echo "	--merged=<file> ... alias for --result for SVN conflict merges"
	exit
fi

if [ -n "${xMine}" ] ; then
	tmpMine=$( echo "${xMine}.mine.tmp" | tr ' !@#$%^&*()+' '____________' )

	echo "Preprocessing 'mine' ${xMine} -> ${tmpMine}"
	decryptProjectFile "${xMine}" "${tmpMine}"
fi

if [ -n "${xTheirs}" ] ; then
	tmpTheirs=$( echo "${xTheirs}.theirs.tmp" | tr ' !@#$%^&*()+' '____________' )

	echo "Preprocessing 'theirs' ${xTheirs} -> ${tmpTheirs}"
	decryptProjectFile "${xTheirs}" "${tmpTheirs}"
fi

if [ -n "${xBase}" ] ; then
	tmpBase=$( echo "${xBase}.base.tmp" | tr ' !@#$%^&*()+' '____________' )

	echo "Preprocessing 'base' ${xBase} -> ${tmpBase}"
	decryptProjectFile "${xBase}" "${tmpBase}"
else
	tmpBase=
fi

if [ -n "${xResult}" ] ; then
	tmpResult=$(echo "${xResult}.merged.tmp" | tr ' !@#$%^&*()+' '____________' )
else
	tmpResult=
fi

echo "Running TortoiseMerge"
echo "    mine = ${tmpMine}"
echo "    theirs = ${tmpTheirs}"
echo "    base = ${tmpBase}"
echo "    merged = ${tmpResult}"

if [ -n "${tmpBase}" ] ; then
	echo "    (processing branch #1)"
	"${TortoiseMergeBinary}" /mine:${tmpMine} /theirs:${tmpTheirs} /base:${tmpBase} /merged:${tmpResult}
	l_merge_return=$?
else if [ -n "${tmpResult}" ] ; then
	echo "    (processing branch #2)"
	"${TortoiseMergeBinary}" /mine:${tmpMine} /theirs:${tmpTheirs} /base:${tmpMine} /merged:${tmpResult}
	l_merge_return=$?
else
	echo "    (processing branch ELSE)"
	"${TortoiseMergeBinary}" ${tmpTheirs} ${tmpMine}
	l_merge_return=$?
	xResult="${xMine}"
	tmpResult="${tmpMine}"
fi ; fi

if [ "${l_merge_return}" -eq 0 ] ; then
	echo "Postprocessing merge result ${tmpResult} -> ${xResult}"
	gawk -f "${LibPath}/_pldev_proj_encrypt_groups.awk" < "${tmpResult}" > "${xResult}"
else
	echo "Merge aborted/failed; no postprocessing taking place!"
fi

echo "Cleaning up the temps"
[ -f "${tmpMine}" ] && rm -f "${tmpMine}"
[ -f "${tmpTheirs}" ] && rm -f "${tmpTheirs}"
[ -f "${tmpBase}" ] && rm -f "${tmpBase}"
[ -f "${tmpResult}" ] && rm -f "${tmpResult}"
