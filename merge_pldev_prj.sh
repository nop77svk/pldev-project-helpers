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

xTheirs="${1:-}"
if [ -z "${xTheirs}" ] ; then
	echo Usage 1:
	echo "    \"${FullScriptPath}\" <theirs/right> <mine/working> [<base/left>] <result/merged>"
	echo Usage 2:
	echo "    \"${FullScriptPath}\" <theirs/left> <mine/right/merged/result>"
	exit
fi

xMine="$2"
if [ -n "${4:-}" ] ; then
	xResult="${4}"
	xBase="${3}"
else if [ -n "${3:-}" ] ; then
	xResult="${3}"
	xBase=
else
	xResult=
	xBase=
fi ; fi

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
else if [ -n "${tmpResult}" ] ; then
	echo "    (processing branch #2)"
	"${TortoiseMergeBinary}" /mine:${tmpMine} /theirs:${tmpTheirs} /base:${tmpMine} /merged:${tmpResult}
else
	echo "    (processing branch ELSE)"
	"${TortoiseMergeBinary}" ${tmpTheirs} ${tmpMine}
	xResult="${xMine}"
	tmpResult="${tmpMine}"
fi ; fi

echo "Postprocessing merge result ${tmpResult} -> ${xResult}"
gawk -f "${LibPath}/_pldev_proj_encrypt_groups.awk" < "${tmpResult}" > "${xResult}"

echo "Cleaning up the temps"
[ -f "${tmpMine}" ] && rm -f "${tmpMine}"
[ -f "${tmpTheirs}" ] && rm -f "${tmpTheirs}"
[ -f "${tmpBase}" ] && rm -f "${tmpBase}"
[ -f "${tmpResult}" ] && rm -f "${tmpResult}"
