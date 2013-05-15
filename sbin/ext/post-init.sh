#!/sbin/busybox sh
# Logging
#/sbin/busybox cp /data/user.log /data/user.log.bak
#/sbin/busybox rm /data/user.log
#exec >>/data/user.log
#exec 2>&1

mkdir /data/.siyah
chmod 777 /data/.siyah

. /res/customconfig/customconfig-helper

ccxmlsum=`md5sum /res/customconfig/customconfig.xml | awk '{print $1}'`
if [ "a${ccxmlsum}" != "a`cat /data/.siyah/.ccxmlsum`" ];
then
  rm -f /data/.siyah/*.profile
  echo ${ccxmlsum} > /data/.siyah/.ccxmlsum
fi
[ ! -f /data/.siyah/default.profile ] && cp /res/customconfig/default.profile /data/.siyah

#check if there is a backup available, check if default profile and active profile are the same
if ls /data/backup.profile &> /dev/null; then
USERPROFILE= cat /data/.siyah/default.profile
DEFAULTPROFILE= cat /res/customconfig/default.profile
#if yes then apply the backup to restore user settings
if [ "$USERPROFILE" = "$DEFAULTPROFILE" ]; then 
cp /data/backup.profile /data/.siyah/default.profile
else
read_defaults
read_config
fi
fi

read_defaults
read_config

#cpu undervolting
echo "${cpu_undervolting}" > /sys/devices/system/cpu/cpu0/cpufreq/vdd_levels

#mdnie sharpness tweak
if [ "$mdniemod" == "on" ];then
. /sbin/ext/mdnie-sharpness-tweak.sh
fi

if [ "$logger" == "on" ];then
insmod /lib/modules/logger.ko
fi

if [ "$frandom" == "on" ];then
insmod /lib/modules/frandom.ko
fi

# disable debugging on some modules
if [ "$logger" == "off" ];then
  rm -rf /dev/log
  echo 0 > /sys/module/ump/parameters/ump_debug_level
  echo 0 > /sys/module/mali/parameters/mali_debug_level
  echo 0 > /sys/module/kernel/parameters/initcall_debug
  echo 0 > /sys//module/lowmemorykiller/parameters/debug_level
  echo 0 > /sys/module/earlysuspend/parameters/debug_mask
  echo 0 > /sys/module/alarm/parameters/debug_mask
  echo 0 > /sys/module/alarm_dev/parameters/debug_mask
  echo 0 > /sys/module/binder/parameters/debug_mask
  echo 0 > /sys/module/xt_qtaguid/parameters/debug_mask
fi

# for ntfs automounting
insmod /lib/modules/fuse.ko
mount -o remount,rw /
mkdir -p /mnt/ntfs
chmod 777 /mnt/ntfs
mount -o mode=0777,gid=1000 -t tmpfs tmpfs /mnt/ntfs
mount -o remount,ro /

/sbin/busybox sh /sbin/ext/properties.sh

/sbin/busybox sh /sbin/ext/install.sh

##### Early-init phase tweaks #####
/sbin/busybox sh /sbin/ext/tweaks.sh

/sbin/busybox mount -t rootfs -o remount,ro rootfs

##### EFS Backup #####
(
# make sure that sdcard is mounted
sleep 30
/sbin/busybox sh /sbin/ext/efs-backup.sh
) &

#apply last soundgasm level on boot
/res/uci.sh soundgasm_hp $soundgasm_hp

# apply STweaks defaults
export CONFIG_BOOTING=1
/res/uci.sh apply
export CONFIG_BOOTING=

#usb mode
/res/customconfig/actions/usb-mode ${usb_mode}

if [ "$Boostpulse" == "on" ];then
#install modded powerhal
su
mount -o remount,rw /system
rm /system/lib/hw/power.default.so
cp /res/power.default.so.boostpulse /system/lib/hw/power.default.so
chown root.root /system/lib/hw/power.default.so
chmod 0664 /system/lib/hw/power.default.so
chown root.system /sys/devices/system/cpu/cpufreq/pegasusq/boostpulse
chmod 664 /sys/devices/system/cpu/cpufreq/pegasusq/boostpulse
echo "1" > /sys/devices/system/cpu/cpufreq/pegasusq/boostpulse
else
#install default powerhal
mount -o remount,rw /system
rm /system/lib/hw/power.default.so
cp /res/power.default.so /system/lib/hw/power.default.so
chown root.root /system/lib/hw/power.default.so
chmod 0664 /system/lib/hw/power.default.so
fi

if [ "$wifi_pm" == "on" ];then
mount -o remount,rw /
echo "1" > /sys/module/dhd/parameters/wifi_pm
else
mount -o remount,rw /
echo "0" > /sys/module/dhd/parameters/wifi_pm
fi


##### init scripts #####
/sbin/busybox sh /sbin/ext/run-init-scripts.sh
