#!/bin/bash -x

TYPE=katello
LV_ORIG=lv_${TYPE}
VG_ORIG=/dev/vg_aeolus
SIZE=20g
RAM=2048


# Remove
vm_remove() {
	virsh destroy ${VM}
	virsh undefine ${VM}
	lvremove --force ${VG_ORIG}/${VM}
}

vm_create() {
	lvcreate --snapshot ${VG_ORIG}/${LV_ORIG} -n ${VM} -L ${SIZE}
	virt-install --name ${VM} --disk=${VG_ORIG}/${VM} --ram=${RAM} --import
}


# exit if no parameters
if [ -z "$1" ]
then
  echo "error: must specify a name to use as a snapsot (e.g. $0 new-name)"
  exit 1
fi

while true; do
  case "$1" in
    -v | --verbose ) VERBOSE=true; shift ;;
    -c | --create ) CREATE=true; NAME=$2; shift; shift; break ;;
    -r | --remove ) REMOVE=true; NAME=$2; shift; shift;  break ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

VM=${TYPE}-${NAME}

vm_remove
if [ "${CREATE}" == "true" ]
then
	vm_create
fi
