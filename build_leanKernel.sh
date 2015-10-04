#!/bin/bash
# leanKernel for Samsung Galaxy Note 3 build script by jcadduono

################### BEFORE STARTING ################
#
# download a working toolchain and extract it somewhere and configure this file
# to point to the toolchain's root directory.
# I highly recommend Christopher83's Linaro GCC 4.9.x Cortex-A15 toolchain.
# Download it here: http://forum.xda-developers.com/showthread.php?t=2098133
#
# once you've set up the config section how you like it, you can simply run
# ./build_leanKernel.sh
# while inside the /leanKernel-note3/ directory.
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

# directory containing cross-compile arm-cortex_a15 toolchain
TOOLCHAIN=/home/jc/build/toolchain/arm-cortex_a15-linux-gnueabihf-linaro_4.9.4-2015.06

# amount of cpu threads to use in kernel make process
THREADS=4

############## SCARY NO-TOUCHY STUFF ###############

export ARCH=arm
export CROSS_COMPILE=$TOOLCHAIN/bin/arm-eabi-
export LOCALVERSION=$KERNEL_VERSION

if ! [ -f $RDIR"/arch/arm/configs/msm8974_sec_hlte_"$VARIANT"_defconfig" ] ; then
	echo "Device variant/carrier $VARIANT not found in arm configs!"
	exit -1
fi

KDIR=$RDIR/arch/arm/boot

CLEAN_BUILD()
{
	echo "Cleaning build..."
	cd $RDIR
	rm -rf build
	mkdir build
	echo "Cleaning up files in $KDIR..."
	rm -f $KDIR/*-zImage
	rm -f $KDIR/*.dtb
	rm -f $KDIR/zImage*
	rm -f $KDIR/ramdisk.img
	rm -f $KDIR/dt.img
	echo "Removing old boot.img..."
	rm -f $RDIR/lk.zip/boot.img
	echo "Removing old zip/tar.md5 files..."
	rm -f $OUT_DIR/$OUT_NAME.zip
	rm -f $OUT_DIR/$OUT_NAME.tar.md5
}

BUILD_KERNEL()
{
	echo "Creating kernel config..."
	cd $RDIR
	mkdir -p build
	make -C $RDIR O=build lk_defconfig \
		VARIANT_DEFCONFIG=msm8974_sec_hlte_"$VARIANT"_defconfig
	echo "Starting build..."
	make -C $RDIR O=build -j"$THREADS"
	cp build/arch/arm/boot/zImage $KDIR/zImage
}

APPEND_DTB()
{
	echo "Appending DTB to zImage..."
	for DTS_FILE in `ls $KDIR/dts/msm8974/msm8974-sec-hlte-*.dts`
	do
		DTB_FILE=${DTS_FILE%.dts}.dtb
		DTB_FILE=$KDIR/${DTB_FILE##*/}
		ZIMG_FILE=${DTB_FILE%.dtb}-zImage
		$RDIR/scripts/dtc/dtc -p 1024 -O dtb -o $DTB_FILE $DTS_FILE
		cat $KDIR/zImage $DTB_FILE > $ZIMG_FILE
	done
}

BUILD_DTIMAGE()
{
	echo "Creating dt.img..."
	$RDIR/tools/dtbTool -o $KDIR/dt.img -s 2048 -p $RDIR/scripts/dtc/ $KDIR/
	chmod a+r $KDIR/dt.img
}

BUILD_RAMDISK()
{
	echo "Building ramdisk.img..."
	cd $RDIR/lk.ramdisk
	find . | cpio -o -H newc | gzip > $KDIR/ramdisk.img
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

if CLEAN_BUILD && BUILD_KERNEL && APPEND_DTB && BUILD_DTIMAGE && BUILD_RAMDISK && BUILD_BOOT_IMG; then
	if [ $MAKE_ZIP -eq 1 ]; then CREATE_ZIP; fi
	if [ $MAKE_TAR -eq 1 ]; then CREATE_TAR; fi
	echo "Finished!"
else
	echo "Error!"
	exit -1
fi
