#!/system/bin/sh

DDIR=/data/data/idlekernel

[ ! -d $DDIR ] && mkdir $DDIR
chmod 755 $DDIR
#
# panel temperature setting
#
CFILE=$DDIR/paneltemp
SFILE=/sys/class/lcd/panel/temperature
CDEF=0
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE
#
# panel color control
#
CFILE=$DDIR/panelcolor
SFILE=/sys/class/lcd/panel/panel_colors
CDEF=2
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE
#
# screen_off_maxfreq
#
CFILE=$DDIR/screen_off_maxfreq
SFILE=/sys/devices/system/cpu/cpufreq
CDEF=1267200
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE/ondemand/screen_off_maxfreq 
echo `cat $CFILE` > $SFILE/interactive/screen_off_maxfreq
#
# scaling_max_freq
#
CFILE=$DDIR/scaling_max_freq
SFILE=/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
CDEF=2265600
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE
#
# cpu governor
#
CFILE=$DDIR/cpu_governor
SFILE=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
CDEF=interactive
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE
#
# gpu governor
#
CFILE=$DDIR/gpu_governor
SFILE=/sys/devices/fdb00000.qcom,kgsl-3d0/devfreq/fdb00000.qcom,kgsl-3d0/governor
CDEF=msm-adreno-tz
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE
#
# tcp congestion control algorithm
#
CFILE=$DDIR/tcp_congestion_control
SFILE=/proc/sys/net/ipv4/tcp_congestion_control
CDEF=cubic
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE
#
# internal memory io scheduler
#
CFILE=$DDIR/io_scheduler_internal
SFILE=/sys/block/mmcblk0/queue/scheduler
CDEF=sio
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE
#
# external memory io scheduler
#
CFILE=$DDIR/io_scheduler_external
SFILE=/sys/block/mmcblk1/queue/scheduler
CDEF=sio
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE
#
# mmc crc
#
CFILE=$DDIR/use_spi_crc
SFILE=/sys/module/mmc_core/parameters/use_spi_crc
CDEF=N
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE
#
# system install SuperSU
#
CFILE=$DDIR/supersu
SFILE=/data/.supersu
CDEF="SYSTEMLESS=false"
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE

/sbin/setonboot apply &

stop thermal-engine
sleep 2
start thermal-engine
