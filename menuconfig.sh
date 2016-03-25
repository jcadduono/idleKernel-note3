#!/bin/bash
# simple script for executing menuconfig

# root directory of idleKernel git repo (default is this script's location)
RDIR=$(pwd)

cd $RDIR
echo "Cleaning build..."
rm -rf build
mkdir build
ARCH=arm make -s -i -C $RDIR O=build ik_defconfig menuconfig
echo "Showing differences between old config and new config"
echo "-----------------------------------------------------"
command -v colordiff >/dev/null 2>&1 && {
	diff -Bwu --label "old config" arch/arm/configs/ik_defconfig --label "new config" build/.config | colordiff
} || {
	diff -Bwu --label "old config" arch/arm/configs/ik_defconfig --label "new config" build/.config
	echo "-----------------------------------------------------"
	echo "Consider installing the colordiff package to make diffs easier to read"
}
echo "-----------------------------------------------------"
echo -n "Are you satisfied with these changes? Y/N: "
read option
case $option in
y|Y)
	cp build/.config arch/arm/configs/ik_defconfig
	echo "Copied new config to arch/arm/configs/ik_defconfig"
	;;
*)
	echo "That's unfortunate"
	;;
esac
echo "Cleaning build..."
rm -rf build
echo "Done."
