#!/system/bin/sh

# selinux fixups
/system/xbin/supolicy --live "allow mediaserver mediaserver_tmpfs file execute"

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
CDEF=fiops
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE
#
# external memory io scheduler
#
CFILE=$DDIR/io_scheduler_external
SFILE=/sys/block/mmcblk1/queue/scheduler
CDEF=fiops
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
#
# uksm
#
CFILE=$DDIR/uksm_run
SFILE=/sys/kernel/mm/uksm/run
CDEF=0
if [ ! -f $CFILE ]; then
	echo $CDEF > $CFILE
fi
echo `cat $CFILE` > $SFILE

/sbin/setonboot apply &
/system/xbin/busybox run-parts /system/etc/init.d &

stop thermal-engine
sleep 2
start thermal-engine

(
	sleep 60;

	BB=/system/xbin/busybox
	
	# stop google service and restart it on boot. this remove high cpu load and ram leak!
	if [ "$($BB pidof com.google.android.gms | wc -l)" -eq "1" ]; then
		$BB kill "$($BB pidof com.google.android.gms)";
	fi;
	if [ "$($BB pidof com.google.android.gms.unstable | wc -l)" -eq "1" ]; then
		$BB kill "$($BB pidof com.google.android.gms.unstable)";
	fi;
	if [ "$($BB pidof com.google.android.gms.persistent | wc -l)" -eq "1" ]; then
		$BB kill "$($BB pidof com.google.android.gms.persistent)";
	fi;
	if [ "$($BB pidof com.google.android.gms.wearable | wc -l)" -eq "1" ]; then
		$BB kill "$($BB pidof com.google.android.gms.wearable)";
	fi;

	# Google Services battery drain fixer by Alcolawl@xda
	# http://forum.xda-developers.com/google-nexus-5/general/script-google-play-services-battery-t3059585/post59563859
	pm enable com.google.android.gms/.update.SystemUpdateActivity
	pm enable com.google.android.gms/.update.SystemUpdateService
	pm enable com.google.android.gms/.update.SystemUpdateService$ActiveReceiver
	pm enable com.google.android.gms/.update.SystemUpdateService$Receiver
	pm enable com.google.android.gms/.update.SystemUpdateService$SecretCodeReceiver
	pm enable com.google.android.gsf/.update.SystemUpdateActivity
	pm enable com.google.android.gsf/.update.SystemUpdatePanoActivity
	pm enable com.google.android.gsf/.update.SystemUpdateService
	pm enable com.google.android.gsf/.update.SystemUpdateService$Receiver
	pm enable com.google.android.gsf/.update.SystemUpdateService$SecretCodeReceiver
)&
