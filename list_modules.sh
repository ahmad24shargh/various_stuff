#! /data/data/com.termux/files/usr/bin/bash

if ! type file > /dev/null; then
  pkg install -y file
fi
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export NC='\033[0m'
export separator=$(awk -v i=$(stty -a <"$(tty)" | grep -Po '(?<=columns )\d+') 'BEGIN { OFS="-"; $i="-"; print }')

list_elf()
{
	sudo find $1 -type f -executable -exec sh -c "file {} | grep -Pi ': elf (32|64)-bit' > /dev/null" \; -print | grep -E '(magisk|ksu|lpu|ap|sus)[^/]*$' | cut -sd / -f 4- | awk '$0="./"$0'
}

clear
if [ $(id -u) -le '1000' ];then
	echo "Error: Cannot run script as root or system"
	exit 1
elif ! command -v termux-setup-storage &>/dev/null ;then
	echo "This script can only be run in termux"
	exit 1
fi


sudo true
[ $? -gt '0' ] && exit



#Close the virtual keyboard
sudo input keycombination 113 57 39

declare -a files
declare -a names
declare -a author
declare -a versions
declare -a ids
files=$(sudo find /data/adb/modules/ -type f -name 'module.prop' 2> /dev/null)

if [[ -z ${files[0]} ]]; then
    echo "No modules were found in /data/adb/modules/ !!"
else
    SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	echo "modules:"
    for each in "${files[@]}"
    do
    	ids+=($(sudo grep  "id=" $each 2> /dev/null | cut -d '=' -f 2))
        var=$(sudo grep "name=" $each 2> /dev/null | cut -d '=' -f 2)
        if [ ! -z "${var}" ]; then
			names+=($var)
			var=$(sudo grep "author=" $each 2> /dev/null | cut -d '=' -f 2)
			if [ ! -z "${var}" ]; then
				author+=($var)
			else
				author+=("unknown")
			fi
			var=$(sudo grep "version=" $each 2> /dev/null | cut -d '=' -f 2)
			if [ ! -z "${var}" ]; then
				versions+=($var)
			else
				versions+=("unknown")
			fi
		fi
    done
fi
counter=0
if [ ${#names[@]} -gt '0' ]; then
    for member in "${names[@]}"; do
    	if sudo test -f "/data/adb/modules/${ids[$counter]}/remove"  ;then
    		status="${RED}REMOVED${NC}"
    	else
			if sudo test -f "/data/adb/modules/${ids[$counter]}/disable" ;then
				status="${RED}DISABLED${NC}"
			else
				#status="${GREEN}ENABLED${NC}"
				status=""
			fi
		fi
        echo -e "$(($counter+1))-$member - ${versions[$counter]}$( [ ! -z "${status}" ] && echo " - ${status}")\n  Author: ${author[$counter]}"
          ##echo "$(echo -n $member | cut -d '=' -f 1) : $(echo -n $member | cut -d '=' -f 2)"
        let counter++
    done
fi

if [ $(sudo find "/data/adb/lspd/config/modules_config.db") ];then
	if ! type "sqlite3" &> /dev/null;then
		pkg install -y sqlite &> /dev/null
	fi
	if ! type "aapt" &> /dev/null;then
		pkg install -y aapt &> /dev/null
	fi
	
	entries=($(sudo sqlite3 /data/adb/lspd/config/modules_config.db  "select mid,module_pkg_name,apk_path,enabled from modules where mid != 1" 2>/dev/null))
	
	if [ "${#entries[@]}" = 0 ]; then
		# No lsposed modules found.
		echo $separator
	else
		counter=1
		echo $separator
		echo "xposed modules:"
    	for entry in "${entries[@]}"; do
    		xposed_badging=$(sudo aapt dump badging $(echo $entry | cut -d "|" -f 3))
    		IFS=$" " names=$(echo $xposed_badging | grep -Eo "application-label:.*" | cut -d : -f 2 )
    		echo "$counter-Name: ${names[0]} - $(echo $xposed_badging | grep -Eo "versionName=[^ ]*" | cut -d " " -f 2 | cut -d = -f 2)$([ $(echo $entry | cut -d "|" -f 4) -eq '0' ] && echo -e " - ${RED}DISABLED${NC}")"
    		echo "  Pakage: $(echo $xposed_badging | grep -Eo "package: name=[^ ]*" | cut -d " " -f 2 | cut -d = -f 2)"
    		let counter++
		done
	fi
fi
echo $separator
echo "List of executable ELF files in /data/adb ..."
list_elf "/data/adb"
echo $separator
IFS=$SAVEIFS
# ss_name="/sdcard/$(date +"$(tr -dc A-Za-z0-9 </dev/urandom | head -c 7)-%F#%X").png"
# sudo screencap -p $ss_name &> /dev/null
# [ -f $ss_name ] && echo "The screenshot was saved in path $ss_name "