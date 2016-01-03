#!/bin/bash
# idleKernel for Samsung Galaxy Note 3 build script by jcadduono
# This build script is for AOSP/CyanogenMod with Kali Nethunter support only
# This build script builds all variants in /ik.ramdisk/variant/

################### BEFORE STARTING ################
#
# download a working toolchain and extract it somewhere and configure this file
# to point to the toolchain's root directory.
# I highly recommend Christopher83's Linaro GCC 4.9.x Cortex-A15 toolchain.
# Download it here: http://forum.xda-developers.com/showthread.php?t=2098133
#
# once you've set up the config section how you like it, you can simply run
# ./build_all.sh
# while inside the /idleKernel-note3/ directory.
#
###################### CONFIG ######################

# root directory of idleKernel git repo (default is this script's location)
RDIR=$(pwd)

[ -z $VER ] && \
# version number
VER=$(cat $RDIR/VERSION)

# output directory of images
OUT_DIR=/home/jc/build/kali-nethunter/AnyKernel2/kernels/lollipop

# directory containing cross-compile arm-cortex_a15 toolchain
TOOLCHAIN=/home/jc/build/toolchain/arm-cortex_a15-linux-gnueabihf-linaro_4.9.4-2015.06

# amount of cpu threads to use in kernel make process
THREADS=5

SET_KERNEL_VERSION()
{
	# kernel version string appended to 3.4.x-idleKernel-hlte-
	# (shown in Settings -> About device)
	KERNEL_VERSION=$VARIANT-$VER-cm12.1-kali
}

############## SCARY NO-TOUCHY STUFF ###############

export ARCH=arm
export CROSS_COMPILE=$TOOLCHAIN/bin/arm-eabi-

KDIR=$RDIR/build/arch/arm/boot

CLEAN_BUILD()
{
	echo "Cleaning build..."
	cd $RDIR
	rm -rf build
	echo "Removing old image files..."
	rm -rf $VARIANT_DIR
}

BUILD_KERNEL()
{
	echo "Creating kernel config..."
	cd $RDIR
	mkdir -p build
	make -C $RDIR O=build ik_defconfig \
		VARIANT_DEFCONFIG=variant_hlte_$VARIANT \
		SELINUX_DEFCONFIG=selinux_never_enforce
	echo "Starting build..."
	make -C $RDIR O=build -j"$THREADS"
}

BUILD_DT_IMG()
{
	echo "Generating dt.img..."
	$RDIR/scripts/dtbTool/dtbTool -o $KDIR/dt.img $KDIR/ -s 2048
}

MOVE_IMAGES()
{
	echo "Moving images to $VARIANT_DIR/..."
	mkdir -p $VARIANT_DIR
	mv $KDIR/zImage $KDIR/dt.img $VARIANT_DIR/
}

mkdir -p $OUT_DIR

for V in eur can kor dcm kdi spr
do
	VARIANT=$V
	VARIANT_DIR=$OUT_DIR/hlte$V
	SET_KERNEL_VERSION
	export LOCALVERSION=$KERNEL_VERSION
	if ! [ -f $RDIR"/arch/arm/configs/variant_hlte_"$VARIANT ] ; then
		echo "Device variant/carrier $VARIANT not found in arm configs!"
		continue
	elif CLEAN_BUILD && BUILD_KERNEL && BUILD_DT_IMG; then
		MOVE_IMAGES
	else
		echo "Error!"
		exit -1
	fi
done;

echo "Finished!"
