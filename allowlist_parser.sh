#!/data/data/com.termux/files/usr/bin/bash
#v0.0.1 alpha

function jumpto
{
    label=$1 
    cmd=$(sed -n "/^:[[:blank:]][[:blank:]]*${label}/{:a;n;p;ba};" $0 | grep -v ':$') 
    eval "$cmd" 
    exit
}

start=${1:-"start"}
#jumpto $start
:  start

SAVEIFS=$IFS
debug_mode=0
if [ $debug_mode -eq 1 ];then
    set -x
fi
echo

if [ "$(echo $PREFIX | grep -q "com.termux";echo $?)" != "0" ];then
	echo "$0 only works in termux !!!"
	errnum=1
	jumpto stop
fi
if [ ! -n $BASH ];then
	echo "$0 has only been tested in bash environment !!!"
	errnum=1
	jumpto stop
fi

errnum=0
allowlist_file_path="/sdcard/.allowlist"
FILE_MAGIC="55534b7f"
let SIZE_OF_RECORDS=776
let KSU_APP_PROFILE_PRESERVE_UID=9999
KSU_DEFAULT_SELINUX_DOMAIN="u:r:su:s0"
separator=$(awk -v i=$(stty -a <"$(tty)" | grep -Po '(?<=columns )\d+') 'BEGIN { OFS="-"; $i="-"; print }')

usage()
{
    echo -e "usage:\n $(basename $0) \"/path/to/allowlist file\""
    echo "If the allowlist file path is not specified,"
    echo "${allowlist_file_path} will be assumed."
    errnum=127
    jumpto stop
}

if ! type xxd > /dev/null; then
  echo "install xxd: pkg install xxd"
  errnum=126
fi
[ $errnum -gt 0 ] && jumpto stop


calc_field_value()
{
	declare -n temp_result=$1
	case $2 in
	"s")
		temp_result="$(dd if=$3 count=$4 skip=$5 bs=1 2>/dev/null | xxd -r -p | tr -d '\0')"
		;;
	"d")
		temp_result="$(printf "%d" 0x$(dd if=$3 count=$4 skip=$5 bs=1 2>/dev/null | fold -w2 | tac | tr -d "\n"))"
		;;
	"b")
		[ "$(dd if=$3 count=$4 skip=$5 bs=1 2>/dev/null |  fold -w2 | tac | tr -d '\n\0')" == "01" ] && temp_result="True" || temp_result="False"
		;;
	*)
		temp_result="ERROR!!!"
		;;
	esac
}

convert_str_to_hex()
{
	declare -n result="$1"
	result="$(printf '%s' "$2" | xxd -p | tr -d '\b\n' | sed -e 's/../\\x&/g')"
}

validate_file_magic()
{
	[ "$(dd if=$1 count=4 bs=1 2>/dev/null | xxd -p)" == "$FILE_MAGIC" ] && return 0 || return 1
}

if [ $# -gt 1 ];then
    echo "The number of arguments is incorrect."
    echo
    usage
fi
if [ ! -z $1 ];then
	find "$1" &>/dev/null
	if [ $? -gt 0 ];then
    	echo "$1 Not found or unavailable"
    	errnum=1
    	jumpto stop
	fi
	if [ ! -f $1 ];then
		echo "$1 isn\'t regular file or unavailable"
    	errnum=1
    	jumpto stop
	fi
	allowlist_file_path=$1	
else
	if [ ! -f "${allowlist_file_path}" ];then
		echo "${allowlist_file_path} Not found"
    	errnum=2
    	jumpto stop
	fi
fi

if ! validate_file_magic ${allowlist_file_path};then
    echo "The file signature (FILE_MAGIC) is not valid."
    errnum=2
    jumpto stop
fi

log_file_name="$(dirname ${allowlist_file_path})/allowlist-$(date +"%F-%X" | tr -d ' :').txt" && touch ${log_file_name}

echolog()
(
    echo "$@"
    echo "$@" >> $log_file_name
)

file_size=$(wc -c ${allowlist_file_path} | cut -d' ' -f1)
record_count=$(((${file_size}-8)/${SIZE_OF_RECORDS}))
if [ "$((${record_count}*${SIZE_OF_RECORDS}+8))" != "${file_size}" ];then
	echo "Invalid file size."
	echo "File size: ${file_size} bytes"	
	echo "Number of records calculated: ${record_count}"
    errnum=3
    jumpto stop
fi
echolog $separator
echolog "allowlist path: ${allowlist_file_path}"
echolog "allowlist size: $file_size bytes,contain $record_count records"
temp_file=$(mktemp)
xxd -p "${allowlist_file_path}" | tr -d '\n' > ${temp_file}

FILE_FORMAT_VERSION=$(printf "%d" 0x$(dd if=${temp_file} count=8 skip=8 bs=1 2>/dev/null | fold -w2 | tac | tr -d "\n"))

declare -a offsets;
result=""
last_offset=$(($(wc -c ${allowlist_file_path} | cut -d' ' -f1)-8))
let c=8
while [ ${c} -lt  $last_offset ];do
	offsets+=(${c})
	let c=${c}+776
done
echolog "FILE_FORMAT_VERSION: v${FILE_FORMAT_VERSION}"
echolog $separator
let current_offset=16
let counter=1
for app_profile in "${offsets[@]}"
do
	#IFS=$SAVEIFS
	echolog "record $counter:"
	let current_offset=$((${app_profile}*2))
	let current_uid=-1
	calc_field_value "result" "d" "${temp_file}" 8 ${current_offset}
	echolog "KSU_APP_PROFILE_VER: v${result}"
	let current_offset+=8
	calc_field_value "result" "s" "${temp_file}" 512 ${current_offset}
	echolog "package name: ${result}"
	let current_offset+=512
	calc_field_value "current_uid" "d" "${temp_file}" 8 ${current_offset}
	echolog -n "Current UID: ${current_uid}"
	if [ $current_uid -eq $KSU_APP_PROFILE_PRESERVE_UID ];then
		echolog " (KSU_APP_PROFILE_PRESERVE_UID=NOBODY_UID)"
	else
		echolog
	fi
	let current_offset+=8
	calc_field_value "allow_su" "b" "${temp_file}" 2 ${current_offset}
	echolog "allow_su: ${allow_su}"
	let current_offset+=16
	calc_field_value "result" "b" "${temp_file}" 2 ${current_offset}
	echolog "use_default: ${result}"
	let current_offset+=2
	if [ "$allow_su" == "False" ];then
		calc_field_value "result" "b" "${temp_file}" 2 ${current_offset}
		echolog "umount_modules: ${result}"
		let current_offset+=2
	else
		calc_field_value "template_name" "s" "${temp_file}" 512 ${current_offset}
		echolog -n "template_name: "
		[ "${template_name}" == '' ] && echolog "EMPTY" || echolog ${template_name}
		let current_offset+=526
		calc_field_value "result" "d" "${temp_file}" 8 ${current_offset}
		echolog "uid: ${result}"
		let current_offset+=8
		calc_field_value "result" "d" "${temp_file}" 8 ${current_offset}
		echolog "gid: ${result}"
		let current_offset+=8
		calc_field_value "result" "d" "${temp_file}" 8 ${current_offset}
		echolog "groups_count: ${result}"
		let current_offset+=8
		calc_field_value "groups" "s" "${temp_file}" 256 ${current_offset}
		echolog -n "groups: "
		[ "${groups}" == '' ] && echolog "EMPTY[]" || echolog ${groups}
		let current_offset+=264
		calc_field_value "result" "d" "${temp_file}" 16 ${current_offset}
		echolog "effective capabilities: ${result}"
		let current_offset+=16
		calc_field_value "result" "d" "${temp_file}" 16 ${current_offset}
		echolog "permitted capabilities: ${result}"
		let current_offset+=16
		calc_field_value "result" "d" "${temp_file}" 16 ${current_offset}
		echolog "inheritable capabilities: ${result}"
		let current_offset+=16
		calc_field_value "selinux_domain" "s" "${temp_file}" 128 ${current_offset}
		echolog -n "selinux_domain: "
		if [ "$selinux_domain" == "$KSU_DEFAULT_SELINUX_DOMAIN" ];then
			echolog "${selinux_domain} (KSU_DEFAULT_SELINUX_DOMAIN)"
		elif [ "${selinux_domain}" == "" ];then
			echolog "EMPTY !!!!"
		else
			echolog "${selinux_domain}"
		fi
		let current_offset+=128
		calc_field_value "result" "d" "${temp_file}" 8 ${current_offset}
		echolog "namespaces: ${result}"
		let current_offset+=8	
	fi
	let counter+=1
	echolog $separator
done
rm -f ${temp_file} &>/dev/null
echolog
[ -s $log_file_name ] && echo "The output report was saved in file $log_file_name"


:  stop
IFS=$SAVEIFS
echo
if [ $debug_mode -eq 1 ];then
    set +x
fi
