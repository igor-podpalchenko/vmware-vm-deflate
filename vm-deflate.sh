#!/bin/bash

DEBUG=1

GUEST_DISK_ROOT_BLOCK_DEV='/dev/sdc'
DUMP_DISK_BLOCK_DEV='/dev/sdb1'

LVM_VG_NAME='centos'
LVM_LV_ROOT_NAME='root'
LVM_LV_SWAP_NAME='swap'
LVM_GUEST_ROOT_DISK="/dev/$LVM_VG_NAME/$LVM_LV_ROOT_NAME";


GUEST_DISK_MOUNT_DIR='/mnt/guest';
DUMP_FILE_NAME='guest-fs.dump'
DUMP_DISK_MOUNT_DIR='/mnt/buffer';
XFS_DUMP_F_PATH="$DUMP_DISK_MOUNT_DIR/$DUMP_FILE_NAME";


# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""
verbose=0
script_mode=0

#_new_root_part_size=0
_new_swap_part_size=0
_new_disk_part_size=0

show_help () {
	echo "Usage: vm-deflate -[s][v]"
	exit
}

while getopts "h?vsf:" opt; do
	case "$opt" in
		h|\?)
			show_help
			exit 0
			;;
		v) verbose=1
			;;
		s) script_mode=1
			;;
		f)  output_file=$OPTARG
			;;
	esac
done
shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift
#echo "verbose=$verbose, output_file='$output_file', Leftovers: $@"

safe_delete () {

	if [ "$script_mode" -eq "1" ]; then
		rm -Rf $1   
		return;
	fi

	read -p "'$1' already exist. Are you sure want to delete it? " -n 1 -r;

	echo    # (optional) move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
        	# do dangerous stuff
		rm -Rf $1
	else
		echo "Script stopped. You should move '$1'"
		exit
	fi
}

continue_or_exit () { 
	
	if [ "$script_mode" -eq "1" ]; then
		return;
	fi

	read -p "$1" -n 1 -r;

	echo    # (optional) move to a new line
	if [[ $REPLY =~ ^[Nn]$ ]]
	then
		exit
	fi
}

ask_for_new_partition_size () {
	echo "DISK:/PRIMARY( $GUEST_DISK_PRIMARY_PART_SIZE )/XFS/TOTAL( $GUEST_DISK_SIZE_TOTAL_H )/USED( $GUEST_DISK_SIZE_USED_H ) and FREE( $GUEST_DISK_SIZE_FREE_H )"
	echo
	echo -n "Please enter new PRIMARY partition size (in GB, no GB postfix): "
	read _new_disk_part_size
}

ask_for_new_swap_size () {
	echo -n "Please enter new SWAP size (in GB, CURRENT SWAP SIZE - '$GUEST_SWAP_SIZE_H') " 
	read _new_swap_part_size
}

generate_xfs_dump () {
	echo "Generating Guest VM root FS (XFS) dump. It may take a while."	
	xfsdump -F -f $XFS_DUMP_F_PATH $GUEST_DISK_MOUNT_DIR
	echo "XFS dump complete"
}

use_existing_dump_or_create_new () {
	
	if [ "$script_mode" -eq "1" ] && [ -f "$XFS_DUMP_F_PATH" ]; then
		echo "Using existing FS dump: $XFS_DUMP_F_PATH"
		return;
	fi

	if [ -f "$XFS_DUMP_F_PATH" ]; then
		read -p "'$XFS_DUMP_F_PATH' already exist. Do you want to regenerate it ? " -n 1 -r;
		echo    # (optional) move to a new line

		if [[ $REPLY =~ ^[Yy]$ ]]
		then
        		# do dangerous stuff
			rm -f $XFS_DUMP_F_PATH
			generate_xfs_dump
		else
			echo "Using existing XFS backup file"
		fi
	else
		generate_xfs_dump
	fi

}


if [ $(whoami) != 'root' ]; then
	echo "Must be root to run $0"
	exit 1;
fi

if [ -d "$DUMP_DISK_MOUNT_DIR" ]; then 
	#try unmount
	umount $DUMP_DISK_MOUNT_DIR > /dev/null 2>&1
	
	safe_delete $DUMP_DISK_MOUNT_DIR;

fi
if [ -d "$GUEST_DISK_MOUNT_DIR" ]; then
	
	# try unmount
	umount $GUEST_DISK_MOUNT_DIR  > /dev/null 2>&1

	safe_delete $GUEST_DISK_MOUNT_DIR;
fi

mkdir $DUMP_DISK_MOUNT_DIR
mkdir $GUEST_DISK_MOUNT_DIR

echo "Mounting guest LVM root filesystem..."
mount $LVM_GUEST_ROOT_DISK $GUEST_DISK_MOUNT_DIR || { echo "Failed to mount '$LVM_GUEST_ROOT_DISK'"; exit; : echo "Mounted '$LVM_GUEST_ROOT_DISK'"; }

echo "Mounting Buffer Filesystem..."
mount $DUMP_DISK_BLOCK_DEV $DUMP_DISK_MOUNT_DIR || { echo "Failed to mount '$DUMP_DISK_BLOCK_DEV'"; exit; : echo "Mounted '$DUMP_DISK_BLOCK_DEV'"; }

GUEST_DISK_PRIMARY_PART_SIZE=`parted $GUEST_DISK_ROOT_BLOCK_DEV unit GB print | sed '/^$/d' | tail -n1 |  awk '{ print $4 }'`

GUEST_DISK_SIZE_TOTAL_H=`df -h $LVM_GUEST_ROOT_DISK | tail -n1 | awk '{print $2}'`
GUEST_DISK_SIZE_USED_H=`df -h $LVM_GUEST_ROOT_DISK | tail -n1 | awk '{print $3}'`
GUEST_DISK_SIZE_FREE_H=`df -h $LVM_GUEST_ROOT_DISK | tail -n1 | awk '{print $4}'`

GUEST_SWAP_SIZE_H=`lvdisplay /dev/$LVM_VG_NAME/$LVM_LV_SWAP_NAME | grep 'LV Size' | awk '{ print $3}'`

BUFFER_DISK_SIZE_TOTAL_H=`df -h $DUMP_DISK_BLOCK_DEV | tail -n1 | awk '{print $2}'`
BUFFER_DISK_SIZE_USED_H=`df -h $DUMP_DISK_BLOCK_DEV | tail -n1 | awk '{print $3}'`
BUFFER_DISK_SIZE_FREE_H=`df -h $DUMP_DISK_BLOCK_DEV | tail -n1 | awk '{print $4}'`

echo "Guest VM root LVM partion (partition): "$GUEST_DISK_SIZE_TOTAL_H
echo "Guest VM root LVM partion (used): "$GUEST_DISK_SIZE_USED_H
echo "Guest VM root LVM partion (free): "$GUEST_DISK_SIZE_FREE_H

#echo "Buffer disk (total): "$BUFFER_DISK_SIZE_TOTAL_H
echo "Buffer disk (used): "$BUFFER_DISK_SIZE_USED_H
echo "Buffer disk (free): "$BUFFER_DISK_SIZE_FREE_H


use_existing_dump_or_create_new 

DUMP_F_SIZE_H=`du -h $XFS_DUMP_F_PATH | tail -n1 | awk '{print $1}'`

echo "Active XFS dump, size: $DUMP_F_SIZE_H"

echo
echo "===================================="
parted $GUEST_DISK_ROOT_BLOCK_DEV unit GB print free
echo "===================================="
echo

_PV_ARGS=`pvdisplay -c`
_PV_ARR=(${_PV_ARGS//:/ })
PV_DEVICE=${_PV_ARR[0]}

_pv_partition_number=`parted $GUEST_DISK_ROOT_BLOCK_DEV unit GB print | sed '/^$/d' | tail -n1 |  awk '{ print $1 }'`

if [ "${_PV_ARR[1]}" != $LVM_VG_NAME ] || [ "$_pv_partition_number" != "2" ]; then
	echo "Physical Volume '$LVM_VG_NAME' not found, aborting."
	echo "or LVM physical volume is not the last partition on disk"
	exit
fi

_PV_ARR2=(${PV_DEVICE//// })
PV_DEVICE_SHORT=${_PV_ARR2[-1]}

BEGIN_SECTOR=`fdisk -l $GUEST_DISK_ROOT_BLOCK_DEV  | grep $PV_DEVICE_SHORT | awk '{print $2}'`


#echo $PV_DEVICE
#echo $PV_DEVICE_SHORT
#echo $BEGIN_SECTOR

ask_for_new_partition_size
ask_for_new_swap_size

#_new_disk_part_size=`echo "$_new_root_part_size + $_new_swap_part_size + 0.53"| bc`

continue_or_exit "Now script will do disk repartitioning. EXISTING DATA ON DISK WILL BE LOST !  Is it ok [y]?"

if [ ! -z "$DEBUG" ]; then

	#set -x
	#trap read debug

	# unmount required
	umount $GUEST_DISK_MOUNT_DIR  > /dev/null 2>&1

	# Disable LVM volumes
	vgchange -a n

	# Remove root LVM physical volume
	pvremove -y $PV_DEVICE  --force --force

	# Remove physical partition from disk
	parted -s $GUEST_DISK_ROOT_BLOCK_DEV rm $_pv_partition_number

	# Create new partition from start sector to defined size
	parted $GUEST_DISK_ROOT_BLOCK_DEV mkpart primary $BEGIN_SECTOR"s" $_new_disk_part_size"GB"

	# Enable LVM for new part
	parted $GUEST_DISK_ROOT_BLOCK_DEV set $_pv_partition_number lvm on

	# Create LVM physical volume (full partition size)
	pvcreate $PV_DEVICE

	# Create LVM volume group
	vgcreate $LVM_VG_NAME $PV_DEVICE

	# Create LVM logical volume SWAP
	lvcreate -y -L $_new_swap_part_size"G" --name $LVM_LV_SWAP_NAME $LVM_VG_NAME

	# Create SWAP FS
	mkswap /dev/$LVM_VG_NAME/$LVM_LV_SWAP_NAME

	# Create ROOT FS
	lvcreate -y -l 100%FREE -n $LVM_LV_ROOT_NAME $LVM_VG_NAME

	# Make new XFS partition
	mkfs.xfs -f $LVM_GUEST_ROOT_DISK

	# Remount FS back to restore dump
	mount $LVM_GUEST_ROOT_DISK $GUEST_DISK_MOUNT_DIR

	# Restore XFS dump
	xfsrestore -f $XFS_DUMP_F_PATH $GUEST_DISK_MOUNT_DIR

	# Make LVS active
	vgchange -a y
fi

VMWARE_DISK_EXTENT=`parted $GUEST_DISK_ROOT_BLOCK_DEV unit S print free | sed '/^$/d' | tail -n1 |  awk '{ print $1 }' | sed 's/.$//'`

echo
echo "Disk resize complete, few minor steps left"
echo "VmWare VMDK extent for optimized disk is: $VMWARE_DISK_EXTENT"
echo "Copy this extent to VMDK file and run: vmkfstools -i input.vmdk -d thin output.vmdk "
