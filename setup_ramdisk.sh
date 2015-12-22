#!/bin/bash
# idleKernel for Samsung Galaxy Note 3 ramdisk setup script by jcadduono
# This script is for Touchwiz Lollipop only

# root directory of idleKernel git repo (default is this script's location)
RDIR=$(pwd)

[ -z $VARIANT ] && \
# device variant/carrier, possible options:
#	att = N900A  (AT&T)
#	can = N900W8 (Canadian, same as T-Mobile)
#	eur = N9005  (Snapdragon International / hltexx / Europe)
#	spr = N900P  (Sprint)
#	tmo = N900T  (T-Mobile, same as Canadian)
#	usc = N900R4 (US Cellular)
#	vzw = N900V  (Verizon)
# korean variants:
#	ktt = N900K  (KT Corporation)
#	lgt = N900L  (LG Telecom)
#	skt = N900S  (South Korea Telecom)
# japanese variants:
#	dcm = N900D / SC-01F  (NTT Docomo)
#	kdi = N900J / SCL22   (au by KDDI)
VARIANT=can

############## SCARY NO-TOUCHY STUFF ###############

if ! [ -d $RDIR"/ik.ramdisk/variant/$VARIANT/" ] ; then
	echo "Device variant/carrier $VARIANT not found in ik.ramdisk/variant!"
	exit -1
fi

CLEAN_RAMDISK()
{
	[ -d $RDIR/build/ramdisk ] && {
		echo "Removing old ramdisk..."
		rm -rf $RDIR/build/ramdisk
	}
}

SET_PERMISSIONS()
{
	echo "Setting ramdisk file permissions..."
	cd $RDIR/build/ramdisk
	# set all directories to 0755 by default
	find -type d -exec chmod 0755 {} \;
	# set all files to 0644 by default
	find -type f -exec chmod 0644 {} \;
	# scripts should be 0750
	find -name "*.rc" -exec chmod 0750 {} \;
	find -name "*.sh" -exec chmod 0750 {} \;
	# init and everything in /sbin should be 0750
	chmod -Rf 0750 init sbin
	chmod 0771 carrier data
}

SETUP_RAMDISK()
{
	echo "Building ramdisk structure..."
	cd $RDIR
	mkdir -p build/ramdisk
	cp -r ik.ramdisk/common/* ik.ramdisk/variant/$VARIANT/* build/ramdisk
	cd $RDIR/build/ramdisk
	mkdir -p dev proc sys system kmod carrier data
	echo "Copying kernel modules to ramdisk..."
	find $RDIR/build -name *.ko -not -path */ramdisk/* -exec cp {} kmod \;
}

CLEAN_RAMDISK
SETUP_RAMDISK
SET_PERMISSIONS

echo "Done setting up ramdisk."
