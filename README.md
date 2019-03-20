# vmware-vm-deflate
Shell script that automates reducing / resizing thin / thick VMDK disks with XFS filesystem.

Disk structure (default layout for CentOS):

	- VmWare VMDK file (disk configuration file)
		- VmWare VMDK flat disk file (binary data)
			- Disk Partition Table
				- Primary 1 boot partition - UEFI BootLoader 
				- Primary 2 LVM member -  LVM
					- VOLUME GROUP (VG) CENTOS (name is configured in script)
						- LOGICAL VOLUME (LV) SWAP
						- LOCICAL VOLUME (LV) ROOT (name is configured in script)
							- XFS VOLUME / - root filesystem
              

Script has following algorithm:

* 1.) Mount BUFFER and GUEST filesystems
* 2.) Create xfsdump for GUEST and store it on BUFFER
* 3.) Repartition GUEST disk - delete existing LVM part / ask for new LVM partition parameters
* 4.) Restore XFS dump into new partition
* 5.) Calculate cut off extent for VMDK file https://virtualman.wordpress.com/2016/02/24/shrink-a-vmware-virtual-machine-disk-vmdk/
* 6.) Manually edit VMDK descriptor file
* 7.) Run "vmkfstools -i input.vmdk -d thin output.vmdk"
* 8.) Attach output.vmdk back to VM


EDIT script configuration BEFORE run.
BACKUP your data before resizing.
