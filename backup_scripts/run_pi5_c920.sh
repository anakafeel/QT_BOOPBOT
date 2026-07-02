#!/bin/sh
# BOOPBOT launcher — select your platform and camera interactively
set -e
cd "$(dirname "$0")"

echo ""
echo "  ██████╗  ██████╗  ██████╗ ██████╗ ██████╗  ██████╗ ████████╗"
echo "  ██╔══██╗██╔═══██╗██╔═══██╗██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝"
echo "  ██████╔╝██║   ██║██║   ██║██████╔╝██████╔╝██║   ██║   ██║   "
echo "  ██╔══██╗██║   ██║██║   ██║██╔═══╝ ██╔══██╗██║   ██║   ██║   "
echo "  ██████╔╝╚██████╔╝╚██████╔╝██║     ██████╔╝╚██████╔╝   ██║   "
echo "  ╚═════╝  ╚═════╝  ╚═════╝ ╚═╝     ╚═════╝  ╚═════╝   ╚═╝   "
echo ""
echo "  CUHacking 2026 — QNX SDP 8.0"
echo ""

# Select board
echo "Select your board:"
echo "  1) Raspberry Pi 4"
echo "  2) Raspberry Pi 5"
echo ""
printf "Enter choice [1-2]: "
read BOARD

# Select camera
echo ""
echo "Select your camera:"
echo "  1) Pi Camera Module 3 (CSI)"
echo "  2) Logitech C920 USB Webcam"
echo ""
printf "Enter choice [1-2]: "
read CAMERA

# Validate
if [ "$BOARD" != "1" ] && [ "$BOARD" != "2" ]; then
    echo "Invalid board selection. Exiting."
    exit 1
fi
if [ "$CAMERA" != "1" ] && [ "$CAMERA" != "2" ]; then
    echo "Invalid camera selection. Exiting."
    exit 1
fi

# Pi Camera Module 3 only supported on Pi4
if [ "$BOARD" = "2" ] && [ "$CAMERA" = "1" ]; then
    echo "WARNING: Pi Camera Module 3 on Pi5 is not yet tested. Proceeding anyway..."
fi

# Set config based on selection
if [ "$BOARD" = "1" ] && [ "$CAMERA" = "1" ]; then
    echo ""
    echo ">> Pi4 + Pi Camera Module 3"
    SENSOR_CMD="sensor -U 521:521 -b external -r /data/share/sensor -c /usr/etc/config/sensor/rpi4_camera_module3.conf"

elif [ "$BOARD" = "1" ] && [ "$CAMERA" = "2" ]; then
    echo ""
    echo ">> Pi4 + Logitech C920 USB Webcam"
    SENSOR_CMD="sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/u3v_camera.conf"

elif [ "$BOARD" = "2" ] && [ "$CAMERA" = "2" ]; then
    echo ""
    echo ">> Pi5 + Logitech C920 USB Webcam"
    echo "   Make sure C920 is in a BLUE USB 3.0 port!"
    SENSOR_CMD="sensor -U 521:521,1001 -b external -r /data/share/sensor -c /data/share/sensor/rpi5_usb_camera.conf"

elif [ "$BOARD" = "2" ] && [ "$CAMERA" = "1" ]; then
    echo ""
    echo ">> Pi5 + Pi Camera Module 3 (experimental)"
    SENSOR_CMD="sensor -U 521:521,1001 -b external -r /data/share/sensor -c /usr/etc/config/sensor/rpi5_camera_module3.conf"
fi

echo ""
echo "Restarting sensor service..."
slay sensor 2>/dev/null || true
slay boopbot 2>/dev/null || true
sleep 1

$SENSOR_CMD &

# Pi5 needs extra time for USB camera init
if [ "$BOARD" = "2" ]; then
    sleep 5
else
    sleep 3
fi

if [ ! -e /dev/sensor/camera1 ]; then
    echo "WARNING: /dev/sensor/camera1 not found. Check camera connection."
fi

export XDG_RUNTIME_DIR=/data/var/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export QT_QPA_PLATFORM=wayland
export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH

echo "Launching boopbot..."
./boopbot
