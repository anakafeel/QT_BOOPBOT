#!/bin/sh
# Run BOOPBOT on QNX SDP 8.0 (Raspberry Pi 4B + Camera Module 3)
set -e
cd "$(dirname "$0")"

SENSOR_CONF=/system/etc/config/sensor/camera_module3.conf

echo "Restarting sensor service..."
slay sensor 2>/dev/null || true
slay boopbot 2>/dev/null || true
sleep 1
sensor -U 521:521 -b external -r /data/share/sensor -c "$SENSOR_CONF" &
sleep 3

if [ ! -e /dev/sensor/camera1 ]; then
    echo "WARNING: /dev/sensor/camera1 not found. Camera may not be connected/configured."
fi

export XDG_RUNTIME_DIR=/data/var/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export QT_QPA_PLATFORM=wayland
export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH

echo "Launching boopbot..."
./boopbot
