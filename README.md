# vmware-vm-deflate

## Shell script that automates reducing unused free space (deflates) / resizing thin / thick VMDK disks with XFS filesystem.
![Result of unused free space deflation](https://raw.githubusercontent.com/igor-podpalchenko/vmware-vm-deflate/master/result.png)

Script uses buffer disk (Attach VmWare disk with ext/xfs for XFS file dumps storage)

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

 1.  ) Mount BUFFER and GUEST filesystems
 1.  ) Create full filesystem dump using xfsdump for GUEST and store it on BUFFER (/mnt/buffer mounted disk)
 1.  ) Repartition GUEST disk - delete existing LVM part.
 1.  ) Script asks for new LVM partition parameters
 1.  ) Restore XFS dump into new partition
 1.  ) Calculate cut off extent for VMDK file https://virtualman.wordpress.com/2016/02/24/shrink-a-vmware-virtual-machine-disk-vmdk/
 1.  ) Manually edit VMDK descriptor file
 1.  ) Run "vmkfstools -i input.vmdk -d thin output.vmdk"
 1.  ) Attach output.vmdk back to VM

Usage:

Attach new VM and install: Linux debian 3.16

Shutdown target VM and attach its VMDK to fixer VM (`/dev/sdc`).

Attach second buffer virtual disk (`/dev/sdb`)
![Attach ](https://raw.githubusercontent.com/igor-podpalchenko/vmware-vm-deflate/master/disks.png)

Install packages: 

```
	sudo apt-get install parted xfsdump xfsprogs lvm2
```

Run:

```
	sudo ./vm-deflate.sh
```

EDIT script configuration **BEFORE** run.
**BACKUP** your data before resizing.
NO responsibility for data loss.

Uncomment those two lines

     set -x
     trap read debug

if you want step by step disk editing commands tracing.
