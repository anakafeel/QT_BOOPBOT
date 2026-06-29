#!/bin/sh
# Run BOOPBOT on QNX SDP 8.0 (Raspberry Pi 5 + Logitech C920 USB Webcam)
# Requires: C920 plugged into a BLUE USB 3.0 port
set -e
cd "$(dirname "$0")"

SENSOR_CONF=/data/share/sensor/rpi5_usb_camera.conf

echo "Restarting sensor service..."
slay sensor 2>/dev/null || true
slay boopbot 2>/dev/null || true
sleep 1

sensor -U 521:521,1001 -b external -r /data/share/sensor -c "$SENSOR_CONF" &
sleep 5

if [ ! -e /dev/sensor/camera1 ]; then
    echo "WARNING: /dev/sensor/camera1 not found. Make sure C920 is in a blue USB 3.0 port."
fi

export XDG_RUNTIME_DIR=/data/var/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export QT_QPA_PLATFORM=wayland
export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH

echo "Launching boopbot..."
./boopbot
