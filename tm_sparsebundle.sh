#!/bin/bash

# Time Machine sparsebundle management tool
# Copyright (C) 2008-2016  Denis Yantarev <denis.yantarev@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

usage() {
	echo "Usage: ${0} [-f] [-s SIZE] command [DEST]"
	echo
	echo "Commands:"
	echo
	echo "  create   Create new limited size sparsebundle for Time Machine sparsebundle"
	echo "           will be copied to DEST directory in manner compatible with mounted"
	echo "           Samba/Windows network shares."
	echo "  resize   Limit existing DEST sparsebundle to specified SIZE."
	echo "  doctor   Try to fix damaged DEST sparsebundle. You must run this as root."
	echo
	echo "Options:"
	echo
	echo "  -s SIZE  Sparsebundle size. Will accept value in bytes (no suffix), kilo- (k),"
	echo "           mega- (m), giga- (g), tera- (t), peta- (p) or exa-bytes (e)."
	echo "           Default value is 1.3x of current machine root filesystem size."
	echo "  -m       Use machine MAC address in a newly created sparsebundle name."
	echo "  -f       Force overwrite in case DEST exists."
	echo
	echo "Please note, if creating sparsebundle on Samba/Windows share you have to execute"
	echo "defaults write com.apple.systempreferences TMShowUnsupportedNetworkVolumes 1"
	echo "to enable non-AppleTalk volumes in Time Machine to select."
}

# Usage: create DIR SIZE OVERWRITE
#   DIR - destination directory
#   SIZE - size in kilobytes
#   OVERWRITE - any value in case overwrite is allowed
create() {
	DIR="${1%%/}"
	SIZE="${2}"
	OVERWRITE="${3}"
	if [ ! -d "${DIR}" ]; then
		echo "Destination directory '${DIR}' does not exist." >&2
		exit 1
	fi
	HOST=`hostname -s`
	if [ "${USE_MAC}" ]; then
		MAC=`ifconfig en0 | awk '$1 ~ /^ether$/ { gsub(/:/, "", $2); print $2; }'`
		BUNDLE="${DIR}/${HOST}_${MAC}.sparsebundle"
	else
		BUNDLE="${DIR}/${HOST}.sparsebundle"
	fi
	if [ -e "${BUNDLE}" ] && [ -z "${OVERWRITE}" ]; then
		echo "'${BUNDLE}' already exists, specify -f to force overwrite." >&2
		exit 1
	fi
	echo "Bundle size is ${SIZE}"
	echo "Creating ${BUNDLE}..."
	TMP_DIR=`mktemp -d`
	TMP_BUNDLE="${TMP_DIR}/${HOST}.sparsebundle"
	hdiutil create -size ${SIZE} -type SPARSEBUNDLE \
		-volname "Backup of ${HOST}" -nospotlight \
		-fs HFS+J -layout NONE "${TMP_BUNDLE}"
	# Remove target sparsebundle if exists
	if [ -e "${BUNDLE}" ]; then
		rm -rf "${BUNDLE}"
	fi
	# mv will not work here, so copy and remove source
	cp -R "${TMP_BUNDLE}" "${BUNDLE}"
	rm -rf "${TMP_DIR}"
}

# Usage: resize BUNDLE SIZE
#   BUNDLE - sparsebundle to resize
#   SIZE - new size in kilobytes
resize() {
	BUNDLE="${1%%/}"
	SIZE="${2}"
	if [ ! -d "${BUNDLE}" ]; then
		echo "'${BUNDLE}' is not a sparsebundle." >&2
		exit 1
	fi
	echo "Resizing to ${SIZE}..."
	# Just in case Info.* files were already user immutable, remove flag
	chflags nouchg "${BUNDLE}/Info.bckup"
	chflags nouchg "${BUNDLE}/Info.plist"
	# Resize sparsebundle
	hdiutil resize -size "${SIZE}" "${BUNDLE}"
	# Make Info.* files user immutable to prevent growth of sparsebundle
	chflags uchg "${BUNDLE}/Info.bckup"
	chflags uchg "${BUNDLE}/Info.plist"
	echo "Note: ${BUNDLE}/Info.* are now user immutable to prevent backup volume growth"
}

# Usage: doctor BUNDLE
#   BUNDLE - sparsebundle to fix
doctor() {
	if [ "$(id -u)" != "0" ]; then
		echo "You must run 'doctor' command as root." >&2
		exit 1
	fi
	BUNDLE="${1%%/}"
	if [ ! -d "${BUNDLE}" ]; then
		echo "'${BUNDLE}' is not a sparsebundle." >&2
		exit 1
	fi
	echo "Repairing ${BUNDLE}..."
	# Reset user immutable flag on sparsebundle contents
	chflags -R nouchg "${BUNDLE}"
	# Attach sparsebundle without mounting and get data partitions list
	ATTACH=$(hdiutil attach -nomount -noverify -noautofsck "${BUNDLE}")
	DEVS=($(echo "${ATTACH}" | awk '{print $1}'))
	DATA_DEVS=($(echo "${ATTACH}" | grep "Apple_HFS" | awk '{print $1}'))
	# fsck data partitions
	for DEV in "${DATA_DEVS[@]}"; do
		echo "Checking '${DEV}'..."
		fsck_hfs -dfr "${DEV}"
  done
	# Detach sparsebundle
	hdiutil detach "${DEVS[0]}"
	# Reset TimeMachine volume error status
	MACHINE_ID="${BUNDLE}/com.apple.TimeMachine.MachineID"
	if [ -f "${MACHINE_ID}" ]; then
		defaults write "${MACHINE_ID}" VerificationState -int 0
		defaults delete "${MACHINE_ID}" RecoveryBackupDeclinedDate
	fi
	echo "Note: now you have to resize sparsebundle again if you did it before"
}

while getopts "fms:" OPT; do
	case "${OPT}" in
		f)
			OVERWRITE=1
			shift
			;;
		s)
			if [[ "${OPTARG}" =~ [0-9]+[kmgtpe]? ]]; then
				SIZE="${OPTARG}"
				shift 2
			else
				echo "Invalid size value: '${OPTARG}'" >&2
				exit 1
			fi
			;;
		m)
			USE_MAC=1
			shift
			;;
		\?)
			echo "Invalid option: -${OPTARG}" >&2
			exit 1
			;;
		:)
			echo "Option -${OPTARG} requires an argument." >&2
			exit 1
			;;
	esac
done

if [ -z "${SIZE}" ]; then
	# Calculate default sparsebundle size (root volume * 1.3)
	SIZE=`df -k | awk '$9 ~ /^\/$/ { print $2; }'`
	SIZE=`LANG=C; printf %.0f $(echo "${SIZE} * 1.3" | bc)`
fi

if [ -z "${1}" ]; then
	echo "Command not specified." >&2
	usage
	exit 1
else
	COMMAND="${1}"
fi

if [ -z "${2}" ]; then
	echo "Destination not specified." >&2
	usage
	exit 1
else
	DEST="${2}"
fi

case "${COMMAND}" in
	create)
		create "${DEST}" "${SIZE}" "${OVERWRITE}"
		;;
	resize)
		resize "${DEST}" "${SIZE}"
		;;
	doctor)
		doctor "${DEST}"
		;;
	*)
		echo "Invalid command: '${COMMAND}'" >&2
		exit 1
		;;
esac
