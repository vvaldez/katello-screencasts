#!/bin/bash

VM=katello
DISK=/dev/vg_aeolus/lv_${VM}

virsh destroy ${VM}
virsh undefine ${VM}

virt-install --accelerate --hvm --connect qemu:///system \
    --network=bridge:br0 \
    --name ${VM} --ram=2048 \
    --vcpus=1 \
    --disk ${DISK} \
    --os-type=linux --os-variant=fedora16 \
    --location=http://172.31.21.3/pub/installers/fedora/16/x86_64/os/ \
    --extra-args="ks=http://172.31.21.3/pub/scripts/ks/f16.cfg"
