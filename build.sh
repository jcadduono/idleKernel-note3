#!/bin/bash
# idleKernel for Samsung Galaxy Note 3 build script by jcadduono

################### BEFORE STARTING ################
#
# download a working toolchain and extract it somewhere and configure this file
# to point to the toolchain's root directory.
# I highly recommend Christopher83's Linaro GCC 4.9.x Cortex-A15 toolchain.
# Download it here: http://forum.xda-developers.com/showthread.php?t=2098133
#
# once you've set up the config section how you like it, you can simply run
# ./build.sh
# while inside the /idleKernel-note3/ directory.
#
###################### CONFIG ######################

# root directory of idleKernel git repo (default is this script's location)
RDIR=$(pwd)

[ "$TARGET" ] ||
# ROM target, possible options:
#	touchwiz (TouchWiz 5.0)
#	touchwiz-G (TouchWiz 5.0 with G series sensorhub)
#	note5port (TouchWiz 5.1, TouchWiz 6.0)
#	aosp-L (CyanogenMod 12.1, SlimROM 5.1)
#	aosp-M (CyanogenMod 13.0, SlimROM 6.0)
TARGET=touchwiz

[ "$VARIANT" ] ||
# device variant/carrier, possible options:
#	att = N900A  (AT&T)
#	can = N900W8 (Canadian, same as T-Mobile)
#	eur = N9005  (Qualcomm International / Europe)
#	spr = N900P  (Sprint)
#	tmo = N900T  (T-Mobile, same as Canadian)
#	usc = N900R4 (US Cellular)
#	vzw = N900V  (Verizon)
# korean variants:
#	ktt = N900K  (KT Corporation)
#	lgt = N900L  (LG Uplus)
#	skt = N900S  (SK Telecom)
# japanese variants:
#	dcm = N900D / SC-01F  (NTT DoCoMo)
#	kdi = N900J / SCL22   (au by KDDI)
VARIANT=can

[ "$VER" ] ||
# version number
VER=$(cat $RDIR/VERSION)

# kernel version string appended to 3.4.x-
# (shown in Settings -> About device)
KERNEL_VERSION=idleKernel-$TARGET-hlte-$VARIANT-$VER

[ -z $PERMISSIVE ] && \
# should we boot with SELinux mode set to permissive? (1 = permissive, 0 = enforcing)
PERMISSIVE=1

# output directory of flashable kernel
OUT_DIR=$RDIR

# output filename of flashable kernel
OUT_NAME=$KERNEL_VERSION

# directory containing cross-compile arm-cortex_a15 toolchain
TOOLCHAIN=$HOME/build/toolchain/arm-cortex_a15-linux-gnueabihf-linaro_4.9.4-2015.06

# amount of cpu threads to use in kernel make process
THREADS=5

############## SCARY NO-TOUCHY STUFF ###############

export ARCH=arm
export CROSS_COMPILE=$TOOLCHAIN/bin/arm-eabi-
export LOCALVERSION=$KERNEL_VERSION

abort() {
	echo "Error: $*"
	exit 1
}

[ -f "$RDIR/arch/arm/configs/target_rom_$TARGET" ] || abort "ROM target $TARGET not found in arm configs!"

[ -f "$RDIR/arch/arm/configs/variant_hlte_$VARIANT" ] || abort "Device variant/carrier $VARIANT not found in arm configs!"

[ "$PERMISSIVE" ] && SELINUX="never" || SELINUX="always"

KDIR=$RDIR/build/arch/arm/boot

CLEAN_BUILD() {
	echo "Cleaning build..."
	cd $RDIR
	rm -rf build
	echo "Removing old zip files..."
	rm -f ik.zip/zImage ik.zip/dtb.img
	rm -f $OUT_DIR/$OUT_NAME.zip
}

BUILD_KERNEL() {
	echo "Creating kernel config..."
	cd $RDIR
	mkdir -p build
	make -C $RDIR O=build ik_defconfig \
		TARGET_DEFCONFIG=target_rom_$TARGET \
		VARIANT_DEFCONFIG=variant_hlte_$VARIANT \
		SELINUX_DEFCONFIG=selinux_${SELINUX}_enforce
	echo "Starting build..."
	make -C $RDIR O=build -j$THREADS
}

CREATE_ZIP() {
	echo "Compressing to TWRP flashable zip file..."
	cd $RDIR/ik.zip
	cp $KDIR/zImage $KDIR/dtb.img ./
	zip -r -9 - * > $OUT_DIR/$OUT_NAME.zip
}

echo "Starting build for $KERNEL_VERSION, SELinux is $SELINUX enforcing..."

CLEAN_BUILD  || abort "Clean failed!"
BUILD_KERNEL || abort "Build failed for $KERNEL_VERSION"
CREATE_ZIP   || abort "Zip creation failed!"

echo "Finished building $KERNEL_VERSION!"
