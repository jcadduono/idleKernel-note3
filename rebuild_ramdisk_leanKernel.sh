#!/bin/bash
# leanKernel ramdisk rebuild script by jcadduono

################### BEFORE STARTING ################
#
# Run ./build_leanKernel.sh first to generate kernel zImage!
#
# Run this file to automatically rebuild the ramdisk and boot.img
# with the contents in lk.ramdisk/ - used for testing ramdisk
# modifications only. There is no need to run this file otherwise.
#
###################### CONFIG ######################

# root directory of LeanKernel git repo (default is this script's location)
RDIR=$(pwd)

# device variant/carrier, possible options:
#	att = N900A (AT&T)
#	can = N900W8 (Canadian, same as T-Mobile)
#	eur = N9005 (Snapdragon International / hltexx / Europe)
#	spr = N900P (Sprint)
#	tmo = N900T (T-Mobile, same as Canadian)
#	usc = N900R (US Cellular)
#	vzw = N900V (Verizon)
VARIANT=tmo

# Kernel version string appended to 3.4.x-leanKernel-hlte-
# (shown in Settings -> About device)
KERNEL_VERSION="$VARIANT-6.4-jc"

# output directory of flashable kernel
OUT_DIR=$RDIR
# output filename of flashable kernel
OUT_NAME=leanKernel-hlte-$KERNEL_VERSION

# should we make a TWRP flashable zip? (1 = yes, 0 = no)
MAKE_ZIP=1

# should we make an Odin flashable tar.md5? (1 = yes, 0 = no)
MAKE_TAR=1

############## SCARY NO-TOUCHY STUFF ###############

KDIR=$RDIR/build/arch/arm/boot

CLEAN_BUILD()
{
	echo "Removing old boot.img..."
	rm -f lk.zip/boot.img
	echo "Removing old zip/tar.md5 files..."
	rm -f $OUT_DIR/$OUT_NAME.zip
	rm -f $OUT_DIR/$OUT_NAME.tar.md5
}

BUILD_RAMDISK()
{
	echo "Building ramdisk.img..."
	cd $RDIR/lk.ramdisk
	mkdir -pm 755 dev proc sys system
	mkdir -pm 771 carrier data
	find | fakeroot cpio -o -H newc | xz -9e --format=lzma > $KDIR/ramdisk.img
	cd $RDIR
}

BUILD_BOOT_IMG()
{
	echo "Generating boot.img..."
	$RDIR/tools/mkbootimg --kernel $KDIR/zImage \
		--ramdisk $KDIR/ramdisk.img \
		--output $RDIR/lk.zip/boot.img \
		--cmdline "quiet console=null androidboot.hardware=qcom user_debug=23 msm_rtb.filter=0x37 ehci-hcd.park=3" \
		--base 0x00000000 \
		--pagesize 2048 \
		--ramdisk_offset 0x02000000 \
		--tags_offset 0x01E00000 \
		--dt $KDIR/dt.img
}

CREATE_ZIP()
{
	echo "Compressing to TWRP flashable zip file..."
	cd $RDIR/lk.zip
	zip -r -9 - * > $OUT_DIR/$OUT_NAME.zip
	cd $RDIR
}

CREATE_TAR()
{
	echo "Compressing to Odin flashable tar.md5 file..."
	cd $RDIR/lk.zip
	tar -H ustar -c boot.img > $OUT_DIR/$OUT_NAME.tar
	cd $OUT_DIR
	md5sum -t $OUT_NAME.tar >> $OUT_NAME.tar
	mv $OUT_NAME.tar $OUT_NAME.tar.md5
	cd $RDIR
}

if CLEAN_BUILD && BUILD_RAMDISK && BUILD_BOOT_IMG; then
	if [ $MAKE_ZIP -eq 1 ]; then CREATE_ZIP; fi
	if [ $MAKE_TAR -eq 1 ]; then CREATE_TAR; fi
	echo "Finished!"
else
	echo "Error!"
	exit -1
fi
