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
	i_script_arg="$1"
	i_option_to_test="$2"
	if bash__SupportsVariableReferences ; then
		declare -n oResult=$3
	fi

	if [[ "${i_script_arg}" == "--${i_option_to_test}="* ]] ; then
		l_script_arg_wo_option_to_test="${i_script_arg#--${i_option_to_test}=}"
		if bash__SupportsVariableReferences ; then
			oResult="${l_script_arg_wo_option_to_test}"
		else
			eval $3=\$l_script_arg_wo_option_to_test
		fi
	else if [ "${i_script_arg}" = "--${i_option_to_test}" ] ; then
		if bash__SupportsVariableReferences ; then
			oResult="${i_option_to_test}"
		else
			eval $3=\$i_option_to_test
		fi
	fi ; fi
}

i_modus_operandi=svn
for l_arg in "$@" ; do
	set_arg "${l_arg}" "svn" i_modus_operandi
	set_arg "${l_arg}" "bzr" i_modus_operandi
	set_arg "${l_arg}" "git" i_modus_operandi

	set_arg "${l_arg}" "mine" i_mine
	set_arg "${l_arg}" "theirs" i_theirs
	set_arg "${l_arg}" "base" i_base
	set_arg "${l_arg}" "result" i_result

	set_arg "${l_arg}" "working" i_mine
	set_arg "${l_arg}" "right" i_theirs
	set_arg "${l_arg}" "left" i_base
	set_arg "${l_arg}" "merged" i_result
done

i_mine="${i_mine:-}"
i_theirs="${i_theirs:-}"
i_result="${i_result:-}"
i_base="${i_base:-}"

# -------------------------------------------------------------------------------------------------

if [ -z "${i_theirs}" -o -z "${i_result}" ] ; then
	cat <<-EOF
		Options:
		    --theirs=<file>     mandatory at least
		    --mine=<file>
		    --base=<file>
		    --result=<file>     mandatory at least
		    --left=<file>       alias for --base for SVN conflict merges
		    --right=<file>      alias for --theirs for SVN conflict merges
		    --working=<file>    alias for --mine for SVN conflict merges
		    --merged=<file>     alias for --result for SVN conflict merges
		EOF
	exit
fi

if [ -n "${i_mine}" ] ; then
	l_tmp_mine=$( echo "${i_mine}.mine.tmp" | tr ' !@#$%^&*()+' '____________' )

	echo "Preprocessing 'mine' ${i_mine} -> ${l_tmp_mine}"
	decryptProjectFile "${i_mine}" "${l_tmp_mine}"
fi

if [ -n "${i_theirs}" ] ; then
	l_tmp_theirs=$( echo "${i_theirs}.theirs.tmp" | tr ' !@#$%^&*()+' '____________' )

	echo "Preprocessing 'theirs' ${i_theirs} -> ${l_tmp_theirs}"
	decryptProjectFile "${i_theirs}" "${l_tmp_theirs}"
fi

if [ -n "${i_base}" ] ; then
	l_tmp_base=$( echo "${i_base}.base.tmp" | tr ' !@#$%^&*()+' '____________' )

	echo "Preprocessing 'base' ${i_base} -> ${l_tmp_base}"
	decryptProjectFile "${i_base}" "${l_tmp_base}"
else
	l_tmp_base=
fi

if [ -n "${i_result}" ] ; then
	l_tmp_result=$(echo "${i_result}.merged.tmp" | tr ' !@#$%^&*()+' '____________' )
else
	l_tmp_result=
fi

echo "Running TortoiseMerge"
echo "    mine = ${l_tmp_mine}"
echo "    theirs = ${l_tmp_theirs}"
echo "    base = ${l_tmp_base}"
echo "    merged = ${l_tmp_result}"

if [ -n "${l_tmp_base}" ] ; then
	echo "    (processing branch #1)"
	"${TortoiseMergeBinary}" /mine:${l_tmp_mine} /theirs:${l_tmp_theirs} /base:${l_tmp_base} /merged:${l_tmp_result}
	l_merge_return=$?
else if [ -n "${l_tmp_result}" ] ; then
	echo "    (processing branch #2)"
	"${TortoiseMergeBinary}" /mine:${l_tmp_mine} /theirs:${l_tmp_theirs} /base:${l_tmp_mine} /merged:${l_tmp_result}
	l_merge_return=$?
else
	echo "    (processing branch ELSE)"
	"${TortoiseMergeBinary}" ${l_tmp_theirs} ${l_tmp_mine}
	l_merge_return=$?
	i_result="${i_mine}"
	l_tmp_result="${l_tmp_mine}"
fi ; fi

if [ "${l_merge_return}" -eq 0 ] ; then
	echo "Postprocessing merge result ${l_tmp_result} -> ${i_result}"
	gawk -f "${LibPath}/_pldev_proj_encrypt_groups.awk" < "${l_tmp_result}" > "${i_result}"
else
	echo "Merge aborted/failed; no postprocessing taking place!"
fi

echo "Cleaning up the temps"
[ -f "${l_tmp_mine}" ] && rm -f "${l_tmp_mine}"
[ -f "${l_tmp_theirs}" ] && rm -f "${l_tmp_theirs}"
[ -f "${l_tmp_base}" ] && rm -f "${l_tmp_base}"
[ -f "${l_tmp_result}" ] && rm -f "${l_tmp_result}"
