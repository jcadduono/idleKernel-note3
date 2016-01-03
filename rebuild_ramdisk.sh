#!/bin/bash
# idleKernel for Samsung Galaxy Note 3 ramdisk rebuild script by jcadduono
# This rebuild script is for AOSP/CyanogenMod Marshmallow only

################### BEFORE STARTING ################
#
# Run ./build.sh first to generate kernel zImage!
#
# Run this file to automatically rebuild the ramdisk and boot.img
# with the contents in ik.ramdisk/ - used for testing ramdisk
# modifications only. There is no need to run this file otherwise.
#
###################### CONFIG ######################

# root directory of idleKernel git repo (default is this script's location)
RDIR=$(pwd)

[ -z $VARIANT ] && \
#	att = N900A  (AT&T)
#	can = N900W8 (Canadian, same as T-Mobile)
#	eur = N9005  (Snapdragon International / hltexx / Europe)
#	spr = N900P  (Sprint)
#	tmo = N900T  (T-Mobile, same as Canadian)
#	usc = N900R4 (US Cellular)
#	vzw = N900V  (Verizon)
# korean variants:
#	kor = N900K/L/S	  (Unified Korean / KT Corporation, LG Telecom, South Korea Telecom)
# japanese variants:
#	dcm = N900D / SC-01F  (NTT Docomo)
#	kdi = N900J / SCL22   (au by KDDI)
VARIANT=can

[ -z $VER ] && \
# version number
VER=6.6.5

# kernel version string appended to 3.4.x-idleKernel-hlte-
# (shown in Settings -> About device)
KERNEL_VERSION=$VARIANT-$VER-cm13.0

[ -z $PERMISSIVE ] && \
# should we boot with SELinux mode set to permissive? (1 = permissive, 0 = enforcing)
PERMISSIVE=1

# output directory of flashable kernel
OUT_DIR=$RDIR
# output filename of flashable kernel
OUT_NAME=idleKernel-hlte-$KERNEL_VERSION

# should we make a TWRP flashable zip? (1 = yes, 0 = no)
MAKE_ZIP=1

# should we make an Odin flashable tar.md5? (1 = yes, 0 = no)
MAKE_TAR=1

############## SCARY NO-TOUCHY STUFF ###############

if ! [ -f $RDIR"/arch/arm/configs/variant_hlte_"$VARIANT ] ; then
	echo "Device variant/carrier $VARIANT not found in arm configs!"
	exit -1
fi

if ! [ -d $RDIR"/ik.ramdisk/variant/$VARIANT/" ] ; then
	echo "Device variant/carrier $VARIANT not found in ik.ramdisk/variant!"
	exit -1
fi

[ $PERMISSIVE -eq 1 ] && SELINUX="permissive" || SELINUX="enforcing"

KDIR=$RDIR/build/arch/arm/boot

CLEAN_BUILD()
{
	echo "Removing old boot.img..."
	rm -f ik.zip/boot.img
	echo "Removing old zip/tar.md5 files..."
	rm -f $OUT_DIR/$OUT_NAME.zip
	rm -f $OUT_DIR/$OUT_NAME.tar.md5
}

BUILD_RAMDISK()
{
	VARIANT=$VARIANT $RDIR/setup_ramdisk.sh
	cd $RDIR/build/ramdisk
	echo "Building ramdisk.img..."
	find | fakeroot cpio -o -H newc | xz --check=crc32 --lzma2=dict=2MiB > $KDIR/ramdisk.cpio.xz
	cd $RDIR
}

BUILD_BOOT_IMG()
{
	echo "Generating boot.img..."
	$RDIR/scripts/mkqcdtbootimg/mkqcdtbootimg --kernel $KDIR/zImage \
		--ramdisk $KDIR/ramdisk.cpio.xz \
		--dt_dir $KDIR \
		--cmdline "quiet console=null androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x3F androidboot.bootdevice=msm_sdcc.1 androidboot.selinux=$SELINUX" \
		--base 0x00000000 \
		--pagesize 2048 \
		--ramdisk_offset 0x02900000 \
		--tags_offset 0x02700000 \
		--output $RDIR/ik.zip/boot.img 
}

CREATE_ZIP()
{
	echo "Compressing to TWRP flashable zip file..."
	cd $RDIR/ik.zip
	zip -r -9 - * > $OUT_DIR/$OUT_NAME.zip
	cd $RDIR
}

CREATE_TAR()
{
	echo "Compressing to Odin flashable tar.md5 file..."
	cd $RDIR/ik.zip
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
