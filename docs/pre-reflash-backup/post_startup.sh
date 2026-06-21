#!/bin/sh

# Configure locations of PAM files.  Note, pamconf must end with a slash
setconf pamlib /system/lib/dll/pam
setconf pamconf /system/etc/pam/

# local/snippets/post_start.custom
# Commands executed from post_startup.sh. Executed at the end of system startup whether slm is in use
# or not
#
# To allow resource managers to be run properly with and without security policies, command lines
# should be written in one of the following forms:
#
#     START(resmgr_t) resmgr DROPROOT(resmgr_uid)
#     STARTU(resmgr_t, resmgr_uid) resmgr
# Where resmgr_t is the security type name (arbitrary but usually the name of the resmgr with _t appended),
# and resmgr_uid is the id to use for both uid and gid.  DROPROOT is used only in cases where the
# resource manager supports a -U option for switching to non-root.
# post_start.~10.hardware
# Start basic HW functionality

echo '---> Starting USB...'
/proc/boot/usb_start.sh
# devb-umass mem name=below1G blk memory=below1G cam pnp
usblauncher_otg -0 -l

io-hid -dusb
waitfor /dev/io-hid/io-hid

echo '---> Starting I2C bus...'
on -u 0:525 i2c-bcm2711 -p0xfe205000 --b100000 --u0
waitfor /dev/i2c0
on -u 0:525 i2c-bcm2711 -p0xfe804000 --b100000 --u1
waitfor /dev/i2c1

echo "---> Starting SPI master driver ..."
on -u 0:524 spi-bcm2711 -c /system/etc/config/spi/spi.conf
waitfor /dev/io-spi

# post_start.~15.networking
# Start or adjust any networking required
. /data/var/etc/settings/network

ip6addrctl install /system/etc/ip6addrctl.conf

if [ ! -z "$IP_ADDR" ] && [ ! "$IP_ADDR" = "dhcp" ]; then
  # Using a static IP so dhcp won't automatically start mdnsd for us
  mdnsd
  on -d -u 50:50  dns-sd -R "XYZ" _airplay._tcp local 500x >/dev/null
fi

# set the host name based on the network settings
if [ ! -z "$HOSTNAME" ]; then
  setconf _CS_HOSTNAME $HOSTNAME
  hostname $HOSTNAME
fi
# post_start.~19.fonts
# Update the font cache on boot when necessary
 
# update the font cache
if [ ! -e /var/cache/fontconfig/CACHEDIR.TAG ]; then
   FONTCONFIG_FILE=/etc/fonts/fonts.conf fc-cache &
fi
# post_start.~20.graphics
# Start screen and the graphics stack

echo '---> Starting Screen...'
chown 36 /dev/io-hid/io-hid
screen -u 36:36 -c /system/lib/graphics/drm-rpi5/graphics-rpi5-2xhdmi.conf >/dev/null 2>&1
echo drop_privileges > /dev/screen/command
waitfor /dev/screen/
# post_start.~21.mtouch
# Start mtouch (touch-screen) input support

if [ -d /dev/screen ]; then
   echo '---> Starting touch drivers...'
   mtouch -c /system/etc/system/config/mtouch.conf -r
fi

# post_start.~23.rpi_resmgrs
# Start the RPI specific resmgrs that depend on screen's VCIO interface

echo '---> Starting RPi drivers...'
rpi_mbox -U 523:523 &
waitfor /dev/mailbox

rpi_gpio -u 522:522 &
waitfor /dev/gpio

rpi_thermal &
waitfor /dev/thermal
# post_start.~25.io-snd
# Start io-snd

#######################################################################
## io-snd startup
#######################################################################
echo '---> Starting Audio io-snd driver...'
io-snd -c /system/etc/system/config/sound/io_snd.conf
# post_start.~30.sensor_framework
# Start sensor framework

echo '---> Starting camera support...'
# Set GPIO  for CSI2 cameras
gpio-bcm2711 set 44 a1 # Set pin 44 to SDA0
gpio-bcm2711 set 45 a1 # Set pin 45 to SCL0

gpio-bcm2711 set 0 ip pd # Pull down pin 0
gpio-bcm2711 set 1 ip pd # Pull down pin 1

# Start VCHIQ and VCSM modules for ISP debayering
bcm-rpi4-vchiq &
waitfor /dev/vchiq
bcm-rpi4-vcsm &
waitfor /dev/vcsm

if [ -d /dev/screen ]; then
    echo '---> Starting sensor framework...'

    # There can only be 1 instance of sensor simultaneously.
    # Only 1 of the sensor commands below must be uncommented.

    # Camera Module 3
    #sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/camera_module3.conf

    # Camera Module 3 bayer data - display with rpi4-debayer-example
    #sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/camera_module3_bayer.conf

    # Video playback of simulator camera i.e. color bars
    #sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/video_playback.conf

    # USB camera
    #sensor -U 521:521 -r /data/share/sensor -c /system/etc/config/sensor/usb_camera.conf

    # USB camera MJPEG format - display with mjpeg_example
    #sensor -U 521:521 -r /data/share/sensor -c /system/etc/config/sensor/usb_camera_jpeg.conf

    # USB3 vision camera: on pi4, you need -b external option to allocate below1G buffers for USB3 vision cameras
    #sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/u3v_camera.conf

    # Simulator camera i.e. color bars
    #sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/sensor_demo.conf
    sensor -U 521:521 -r /data/share/sensor -c /system/etc/config/sensor/usb_camera.conf

    # Intel D435 depth camera - z16 depth map and ycbycr color image
    #sensor -U 521:521 -r /data/share/sensor -c /system/etc/config/sensor/d435_z16_ycbycr.conf

    # Intel D435 depth camera - rgb565 depth map image and ycbycr color image
    #sensor -U 521:521 -r /data/share/sensor -c /system/etc/config/sensor/d435_rgb565_ycbycr.conf

    waitfor /dev/sensor/camera1
fi

# post_start.~96.multimedia
# Start the mm-renderer process for multimedia playback

/system/sbin/mm-renderer -C /system/etc/mm/mm-renderer.conf

if [ ! -d /dev/mm-renderer ]; then
    echo ""
    echo "ERROR: Failed to launch mm-renderer. No multimedia playback will be available."
    echo ""
fi

echo Process count:`pidin arg | wc -l`

exit 0
