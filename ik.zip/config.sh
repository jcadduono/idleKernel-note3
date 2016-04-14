#!/sbin/sh

## start config variables

tmp=/tmp/idlekernel
# leave boot_block empty for automatic (searches recovery.fstab and other locations)
boot_block=/dev/block/platform/msm_sdcc.1/by-name/boot
bin=$tmp/tools
ramdisk=$tmp/ramdisk
ramdisk_patch=$ramdisk-patch
split_img=$tmp/split-img
default_prop=$ramdisk/default.prop

## end config variables

