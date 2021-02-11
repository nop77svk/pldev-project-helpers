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

# -------------------------------------------------------------------------------------------------

for prjFile in *.prj ; do
	echo "Now checking project file ${prjFile}" >&2

	echo "    Spooling the list of files in PRJ" >&2
	cat "${Here}/${prjFile}" \
		| dos2unix \
		| gawk '
			BEGIN {
				doSpool = 0;
			}
	
			$0 ~/^[[:space:]]*\[.*\][[:space:]]*$/ {
				doSpool = 0;
			}
	
			doSpool == 1 {
				print;
			}
	
			$0 ~/^[[:space:]]*\[Files\][[:space:]]*$/ {
				doSpool = 1;
			}
		' \
		| sed 's/^[^,]*,[^,]*,[^,]*,[^,]*,\s*\(.*\)\s*$/\1/gi' \
		| grep -Ev '^\s*$' \
		| tr '[:upper:]' '[:lower:]' \
		| /bin/sort \
		> "${TmpPath}/file_list_prj.${RndToken}.tmp"

	echo "    Spooling the list of files on filesystem" >&2
	cd "${Here}"
	/bin/find -L . \( -xtype f -o -xtype l \) \
			-a -not \( -iname '*.tmp' -o -iname '*.log' -o -iname '*.~???' -o -iname '*.~??' -o -iname '*.out' \) \
			-a -not \( -ipath './_aux/*' -o -ipath './.*/*' -a -not -ipath './.deploy/_schemas.config.*' \) \
			-a -not \( -ipath './_schemas.config' -o -ipath './.bzrignore' -o -ipath './cross_check_prj_vs_filesystem.sh' -o -ipath './dqm_engine.dsk' -o -ipath './dqm_engine.prj' -o -ipath './readme.txt' \) \
		| grep -Ev '^\s*$' \
		| sed '
			s/^.\///g
			s/\//\\/g
		' \
		| tr '[:upper:]' '[:lower:]' \
		| /bin/sort \
		> "${TmpPath}/file_list_real.${RndToken}.tmp"

	echo "    Comparing the lists" >&2

	echo "        Generating list of scripts not found in PRJ file / extra on filesystem"
	comm -13 "${TmpPath}/file_list_prj.${RndToken}.tmp" "${TmpPath}/file_list_real.${RndToken}.tmp" \
		> "${TmpPath}/extra_files.${RndToken}.tmp"

	echo "        Generating list of scripts not found on filesystem / extra in PRJ file"
	comm -23 "${TmpPath}/file_list_prj.${RndToken}.tmp" "${TmpPath}/file_list_real.${RndToken}.tmp" \
		> "${TmpPath}/extra_PRJ_items.${RndToken}.tmp"

	echo "    Decrypting project's file groups"
	gawk -f "${LibPath}/_pldev_proj_decrypt_groups.awk" "${prjFile}" > "${TmpPath}/${prjFile}.${RndToken}.base.tmp"

	echo "    Removing extra project items"
	grep -Fv --file="${TmpPath}/extra_PRJ_items.${RndToken}.tmp" "${TmpPath}/${prjFile}.${RndToken}.base.tmp" > "${TmpPath}/${prjFile}.${RndToken}.no_extra_items.tmp"

	echo "    Adding extra files to project"
	gawk -v "extraFilesList=${TmpPath}/extra_files.${RndToken}.tmp" '
		{
			print;
		}

		$0 == "[GroupedFiles]" {
			while (getline newItem < extraFilesList)
			{
				match(newItem, /\.[^.]+/, xx);
				if (RLENGTH <= 0)
					prefix = "1,0,,,";
				else {
					newItemExt = xx[1];
					if (newItemExt ~ /\.(cmd|sh)$/)
						prefix = "0,0,,,";
					else if (newItemExt ~ /\.(pck|pkg|spc|bdy|pks|pkb|typ|tps|tpb|typ|trg)$/)
						prefix = "3,4,,,";
					else if (newItemExt ~ /\.(sql|pdc)/)
						prefix = "1,0,,,";
					else
						prefix = "1,0,,,";
				}
				print "group{new};item{" prefix newItem "}";
			}
		}
	' "${TmpPath}/${prjFile}.${RndToken}.no_extra_items.tmp" \
		> "${TmpPath}/${prjFile}.${RndToken}.synced.tmp"

	echo "    Encrypting project's file groups"
	gawk -f "${LibPath}/_pldev_proj_encrypt_groups.awk" "${TmpPath}/${prjFile}.${RndToken}.synced.tmp" \
		> "${TmpPath}/${prjFile}.${RndToken}.new"
done

echo "CleanUp"
[ -z "${DEBUG}" ] && (
	rm -f "${TmpPath}/file_list_prj.${RndToken}.tmp"
	rm -f "${TmpPath}/file_list_real.${RndToken}.tmp"
	rm -f "${TmpPath}/extra_PRJ_items.${RndToken}.tmp"
	rm -f "${TmpPath}/extra_files.${RndToken}.tmp"
	rm -f "${TmpPath}/${prjFile}.${RndToken}.base.tmp"
	rm -f "${TmpPath}/${prjFile}.${RndToken}.no_extra_items.tmp"
	rm -f "${TmpPath}/${prjFile}.${RndToken}.synced.tmp"
)

echo "DONE" >&2
