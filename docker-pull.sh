#!/usr/bin/env bash

usage() {
	echo "usage: $0 image tag"
	echo "       $0 user image tag"
	exit 1
}

check_result() {
	if [ $1 -ne 0 ]; then
		echo "[ERROR] $2"
		exit $1
	fi
}

info() {
	echo "[INFO] $1"
}

warning() {
	echo "[WARNING] $1"
}

if [ "$#" -eq 2 ]; then
	newDir="$1"
	imageName="$1:$2"
elif [ "$#" -eq 3 ]; then
	# TODO this doesn't work because moby script encounters auth error
	#	while downloading the image
	newDir="$2"
	imageName="$1/$2:$3"
else
	usage
fi

info "Pulling docker image '${imageName}'s layers into ${newDir}/image-files."

mkdir ${newDir}
check_result $? "Couldn't create directory ${newDir}."
cd ${newDir}

mkdir image-files
check_result $? "Couldn't create directory ${newDir}/image-files."

/home/boraozarslan/.scripts/moby image-files/ $1:$2
check_result $? "Moby script failed."

info "Creating the filesystem of the corresponding image into ${newDir}/fs."

mkdir fs
check_result $? "Couldn't create directory ${newDir}/fs."

for layer in $(find . -name layer.tar); do
	# XXX: Need sudo because some names are special and can't extract them
	sudo tar -xvf ${layer} -C fs
	check_result $? "Couldn't tar -xvf the file '${layer}'."
done

# XXX: Brand each ELF executable to be a Linux binary because Linux doesn't
#	do this they're all set to 0. Linuxulator can only run it then.
info "Branding each ELF binary as Linux binary."

for file in $(sudo find ./fs -perm +111); do
	# XXX:	Requires sudo because some files are special
	#	A lot of errors because the script loops through every file
	#	with an executable bit set and tries to brand them as Linux
	#	ELF binary but files like shell scripts or directories with
	#	executable will also be caught. So keep brandelf quite
	#	because they just fail without any problems.

	# Also skip branding some symlinks 
	# for example some-symlink -> /dev/stdout freezes
	if [ ! -L ${file} ]; then
		sudo brandelf -t Linux ${file} 2> /dev/null
	fi
done

info "Trying to mount devfs, linsysfs and linprocfs."

devFs="./fs/dev"
sysFs="./fs/sys"
procFs="./fs/proc"

if [ -e ${devFs} ]; then
	sudo mount -t devfs devfs ${devFs}
	check_result $? "Couldn't mount devfs."
else
	warning "Couldn't mount devfs. Image doesn't have /dev."
fi

if [ -e ${sysFs} ]; then
	sudo mount -t linsysfs linsysfs ${sysFs}
	check_result $? "Couldn't mount linsysfs."
else
	warning "Couldn't mount linsysfs. Image doesn't have /sys."
fi

if [ -e ${procFs} ]; then
	sudo mount -t linprocfs linprocfs ${procFs}
	check_result $? "Couldn't mount linprocfs."
else
	warning "Couldn't mount linprocfs. Image doesn't have /proc."
fi

info "setup-docker is done."
