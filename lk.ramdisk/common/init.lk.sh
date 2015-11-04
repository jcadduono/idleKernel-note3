#!/system/bin/sh

# selinux fixups
/system/xbin/supolicy --live \
	"allow mediaserver mediaserver_tmpfs file execute"

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
# cpu governor
#
CFILE="/data/data/leankernel/cpu_governor"
SFILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
[ -f $CFILE ] && echo `cat $CFILE` > $SFILE
#
# gpu governor
#
CFILE="/data/data/leankernel/gpu_governor"
SFILE="/sys/devices/fdb00000.qcom,kgsl-3d0/devfreq/fdb00000.qcom,kgsl-3d0/governor"
[ -f $CFILE ] && echo `cat $CFILE` > $SFILE
#
# tcp congestion control algorithm
#
CFILE="/data/data/leankernel/tcp_congestion_control"
SFILE="/proc/sys/net/ipv4/tcp_congestion_control"
[ -f $CFILE ] && echo `cat $CFILE` > $SFILE
#
# internal memory io scheduler
#
CFILE="/data/data/leankernel/io_scheduler_internal"
SFILE="/sys/block/mmcblk0/queue/scheduler"
[ -f $CFILE ] && echo `cat $CFILE` > $SFILE
#
# external memory io scheduler
#
CFILE="/data/data/leankernel/io_scheduler_external"
SFILE="/sys/block/mmcblk1/queue/scheduler"
[ -f $CFILE ] && echo `cat $CFILE` > $SFILE
#
# mmc crc
#
CFILE="/data/data/leankernel/use_spi_crc"
SFILE="/sys/module/mmc_core/parameters/use_spi_crc"
[ -f $CFILE ] && echo `cat $CFILE` > $SFILE

stop thermal-engine
/system/xbin/busybox run-parts /system/etc/init.d
start thermal-engine
