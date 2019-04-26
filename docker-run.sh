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

# entrypoint is the initial command if it exists
entrypoint=$(cat ${configJson} | jq '.config.Entrypoint[]' 2>/dev/null)
if [[ $? == 0 ]]; then
	# Command did not fail so entrypoint exists as array
	while read line; do
		entrypoint2=$(echo ${line} | sed 's/^"//g')
		entrypoint3=$(echo ${entrypoint2} | sed 's/"$//g')
		dockerRun[${index}]=${entrypoint3}
		index=$((index+1))
	done < <(cat ${configJson} | jq '.config.Entrypoint[]')
else
	# Entrypoint is sometimes not in an array
	entrypoint=$(cat ${configJson} | jq '.config.Entrypoint')
	# This will always return 0 because config exists
	if [[ ${entrypoint} != "null" ]]; then
		# strip the quotation marks
		entrypoint2=$(echo ${entrypoint} | sed 's/^"//g')
		entrypoint3=$(echo ${entrypoint2} | sed 's/"$//g')
		dockerRun[${index}]=${entrypoint3}
		index=$((index+1))
	fi
fi

# Command is the default parameter/command
commands=$(cat ${configJson} | jq '.config.Cmd[]' 2>/dev/null)
if [[ $? == 0 ]]; then
	while read line; do
		arg2=$(echo ${line} | sed 's/^"//g')
		arg3=$(echo ${arg2} | sed 's/"$//g')
		dockerRun[${index}]=${arg3}
		index=$((index+1))
	done < <(cat ${configJson} | jq '.config.Cmd[]')
fi

info "Expected Environment Variables:"
while read line; do
	echo -e "\t${line}"
done < <(cat ${configJson} | jq '.config.Env[]')
echo ""

# Print out commands docker would have run before running the command
setup=$(cat ${configJson} | jq '.config.Run[]' 2>/dev/null)
# Run can be in an array even though most of the time it is not but check for
# it anyways
if [[ $? == 0 ]]; then
	info "Docker's setup commands before running:"
	while read line; do
		setup2=$(echo ${line} | sed 's/^"//g')
		setup3=$(echo ${setup2} | sed 's/"$//g')
		echo -e "\t${setup3}"
	done < <(cat ${configJson} | jq '.config.Run[]' 2>/dev/null)
	echo ""
else
	setup=$(cat ${configJson} | jq '.config.Run')
	# This will always return 0 because config exists
	if [[ ${setup} != "null" ]]; then
		info "Docker's setup command before running:"
		setup2=$(echo ${setup} | sed 's/^"//g')
		setup3=$(echo ${setup2} | sed 's/"$//g')
		echo -e "\t${setup3}"
		echo ""
	fi
fi

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
