#!/bin/bash

VM=katello
DISK=/dev/vg_aeolus/lv_${VM}
LOCATION=http://172.31.21.3/pub/installers/fedora/16/x86_64/os/
KICKSTART=http://172.31.21.3/pub/scripts/ks/f16.cfg
BRIDGE=br0
RAM=2048
VCPUS=1
OS_TYPE=linux
OS_VARIANT=fedora16

virsh destroy ${VM}
virsh undefine ${VM}

virt-install --accelerate --hvm --connect qemu:///system \
    --network=bridge:${BRIDGE} \
    --name ${VM} --ram=${RAM} \
    --vcpus=${VCPUS} \
    --disk ${DISK} \
    --os-type=${OS_TYPE} --os-variant=${OS_VARIANT} \
    --location=${LOCATION} \
    --extra-args="ks=${KICKSTART}"
