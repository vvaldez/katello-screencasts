#!/bin/bash -x

LV_ORIG=lv_katello
VG_ORIG=/dev/vg_aeolus
SIZE=20g
RAM=2048

# exit if no parameters
if [ -z "$1" ]
then
  echo "error: must specify a name to use as a snapsot (e.g. $0 new-name)"
  exit 1
else
  NAME=$1
fi

VM=katello-${NAME}

# Remove
vm_remove() {
	lvremove --force ${VG_ORIG}/${VM}
	virsh destroy ${VM}
	virsh undefine ${VM}
}

vm_create() {
	lvcreate --snapshot ${VG_ORIG}/${LV_ORIG} -n ${VM} -L ${SIZE}
	virt-install --name ${VM} --disk=${VG_ORIG}/${VM} --ram=${RAM} --import
}

vm_remove
vm_create
