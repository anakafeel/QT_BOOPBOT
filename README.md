# BOOPBOT

A Qt Quick application for QNX SDP 8.0, running on a Raspberry Pi 4B with a Pi Camera Module 3.
Built for CUHacking.terminal-themed UI with a live camera feed panel and API control buttons.

<img width="975" height="743" alt="image" src="https://github.com/user-attachments/assets/187c491f-1129-43a5-87df-2d1e21a2b25c" />


## Status

**Camera feed: WORKING** ✅ — live real-time stream from Pi Camera Module 3 via QNX Sensor Framework 8.0.4.

## Hardware / OS requirements

- Raspberry Pi 4B
- Raspberry Pi Camera Module 3 (imx708 sensor)
- QNX QSTI build 297 (June 6 2026) or newer flashed to SD card
- Qt 6.10 installed via `apk` on the target
- A Wayland session running on the target (Weston), accessible over TigerVNC for development

## Quick start

```sh
git clone git@github.com:anakafeel/QT_BOOPBOT.git boopbot
cd boopbot
./build.sh
./run.sh
```

## Prerequisites (must install on QNX target before building)

```sh
# Qt
apk add qt6-base qt6-base-dev qt6-declarative qt6-declarative-dev qt6-wayland

# Sensor framework — THIS IS CRITICAL, camera will not work without it
apk add qnx-sensor-framework \
        qnx-sensor-framework-dev \
        qnx-sensor-framework-camera-imx708 \
        qnx-sensor-framework-camera-imx708-demo \
        qnx-sensor-framework-utils
```

## What fixed the camera (short version)

Both bugs were fixed in qnx-sensor-framework 8.0.4, available via apk on QSTI build 297+. Also required using /usr/etc/config/sensor/rpi4_camera_module3.conf and real camera headers from qnx-sensor-framework-dev. See docs/qt-qnx-setup-guideV3.md Part 9 for the full story.

## Camera service setup (manual)

```sh
slay sensor 2>/dev/null
sensor -U 521:521 -b external -r /data/share/sensor \
       -c /usr/etc/config/sensor/rpi4_camera_module3.conf &
sleep 3
ls /dev/sensor/
```

## Debugging tips

- slog2info | grep -i camapi | tail -20
- Camera STATUS panel in UI shows live CameraWorker status
- If MESA GPU memory errors appear after crashes, reboot the Pi
- camera_example3_viewfinder can verify sensor service independently
