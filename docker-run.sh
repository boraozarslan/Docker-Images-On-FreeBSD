#!/usr/bin/env bash

check_result() {
	if [ $1 -ne 0 ]; then
		echo "[ERROR] $2"
		exit $1
	fi
}

info() {
	echo "[INFO] $1"
}

if [ ! -e image-files/manifest.json ]; then
	check_result 1 "Missing the manifest.json file."
fi

# TODO can there be more than one entry in manifest.json?
#	probably, why would it be in an array otherwise
#	just grab the first one for now
configJsonWithQuotes=$(cat image-files/manifest.json | jq '.[0].Config')
configJson=image-files/${configJsonWithQuotes:1:-1}

if [ ! -e ${configJson} ]; then
	check_result 1 "Missing the config json file."
fi

count=0

for jsonFile in $(ls image-files/*.json); do
	count=$((count+1))
done

if [ ${count} -gt 2 ]; then
	check_result 1 "Don't know what to do when there is more than 2 json files."
fi

declare -a dockerRun
index=0

while read line; do
	arg2=$(echo ${line} | sed 's/^"//g')
	arg3=$(echo ${arg2} | sed 's/"$//g')
	dockerRun[${index}]=${arg3}
	index=$((index+1))
done < <(cat ${configJson} | jq '.config.Cmd[]')

info "Expected Environment Variables:"
while read line; do
	echo -e "\t${line}"
done < <(cat ${configJson} | jq '.config.Env[]')

# Find where the binary is from the assumed PATH

root=$(pwd)/fs

# XXX: Assume PATH is the first variable which seems to be true
EnvPath=$(cat ${configJson} | jq '.config.Env[0]')
EnvPath=${EnvPath:6:-1}
SplitPath=$(echo ${EnvPath} | tr ":" " ")

index=0
for eachPath in ${SplitPath}; do
	filePath=${root}${eachPath}/${dockerRun[0]}
	if [[ ${index} -eq 0  && -x ${filePath} ]]; then
		dockerRun[0]=${eachPath}/${dockerRun[0]}
		index=$((index+1))
	fi
done

info "Run the image as 'sudo chroot ${root} ${dockerRun[*]}'"
