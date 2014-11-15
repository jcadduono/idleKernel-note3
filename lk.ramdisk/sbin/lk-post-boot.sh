#!/system/bin/sh

#
# replace (u)random with erandom
#
rm -f /dev/urandom
ln -s /dev/erandom /dev/urandom
rm -f /dev/random
ln -s /dev/erandom /dev/random

[ ! -d "/data/data/leankernel" ] && mkdir /data/data/leankernel
chmod 755 /data/data/leankernel
#
# panel temperature setting
#
PANELTMP="/data/data/leankernel/paneltemp"
PANELSF="/sys/class/lcd/panel/temperature"
[ -f $PANELTMP ] && echo `cat $PANELTMP` > $PANELSF
#
# panel color control
#
PANELCLR="/data/data/leankernel/panelcolor"
PANELSF="/sys/class/lcd/panel/panel_colors"
[ -f $PANELCLR ] && echo `cat $PANELCLR` > $PANELSF
#
# screen_off_maxfreq
#
CFILE="/data/data/leankernel/screen_off_maxfreq"
SFILE="/sys/devices/system/cpu/cpufreq"
if [ -f $CFILE ]; then
  echo `cat $CFILE` > $SFILE/ondemand/screen_off_maxfreq 
  echo `cat $CFILE` > $SFILE/interactive/screen_off_maxfreq
fi
#
# scaling_max_freq
#
CFILE="/data/data/leankernel/scaling_max_freq"
SFILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
[ -f $CFILE ] && echo `cat $CFILE` > $SFILE
#
# gpu governor
#
CFILE="/data/data/leankernel/gpu_governor"
SFILE="/sys/devices/fdb00000.qcom,kgsl-3d0/devfreq/fdb00000.qcom,kgsl-3d0/governor"
[ -f $CFILE ] && echo `cat $CFILE` > $SFILE
#
# MMC CRC
#
CFILE="/data/data/leankernel/use_spi_crc"
SFILE="/sys/module/mmc_core/parameters/use_spi_crc"
[ -f $CFILE ] && echo `cat $CFILE` > $SFILE

# daemonsu support - probably not needed
if [ -f "/system/xbin/daemonsu" ]; then
   [ ! "`ps | grep daemonsu`" ] && /system/xbin/daemonsu --auto-daemon &
fi

stop thermal-engine
/system/xbin/busybox run-parts /system/etc/init.d
start thermal-engine
