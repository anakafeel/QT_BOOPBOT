#!/bin/sh
# One-time setup: install all required packages on a fresh QNX image
# Run this ONCE before building, then use ./build.sh and ./run.sh normally
# Covers: Pi4 + Pi Camera Module 3, Pi4 + C920, Pi5 + C920
set -e

echo "=== Installing Qt6 ==="
apk add qt6-base qt6-base-dev qt6-declarative qt6-declarative-dev qt6-wayland

echo "=== Installing sensor framework (base) ==="
apk add qnx-sensor-framework \
        qnx-sensor-framework-dev \
        qnx-sensor-framework-utils

echo "=== Installing Pi4 CSI camera support (Pi Camera Module 3) ==="
apk add qnx-sensor-framework-camera-imx708 \
        qnx-sensor-framework-camera-imx708-demo \
        qnx-sensor-framework-rpi-camera-ipa

echo "=== Installing Pi5 sensor framework ==="
apk add qnx-sensor-framework-rpi5

echo "=== Installing multimedia framework (sensor framework dependency) ==="
apk add qnx-multimedia-framework

echo "=== Installing updated xHCI USB driver (REQUIRED for Pi5 USB camera) ==="
apk add qnx-devu-hcd-dwc3-xhci

echo "=== Installing libyuv (for format conversions) ==="
apk add libyuv

echo "=== Creating libsfc_libyuv symlink ==="
ln -sf /usr/lib/libyuv.so /usr/lib/libsfc_libyuv.so 2>/dev/null || true

echo "=== Creating sensor config directory ==="
mkdir -p /data/share/sensor

echo "=== Creating Pi5 USB camera sensor config ==="
cat > /data/share/sensor/rpi5_usb_camera.conf << 'CONFEOF'
begin SENSOR_GLOBAL
    external_platform_library_path = libsensor_platform_broadcom_rpi5.so
    external_platform_library_variant = PLATFORM_VARIANT_BCM2712
end SENSOR_GLOBAL
begin SENSOR_UNIT_1
    type = usb_camera
    name = front-camera
    position = 0, 0, 0
    direction = 0, 0, 0
    default_video_framerate = 30
    address = /dev/usb/io-usb-otg, -1, -1, -1, -1
    num_user_buffers = 12
    user_queue_depth = 4
end SENSOR_UNIT_1
begin INTERIM_DATA_UNIT_1
    num_buffers = 5
    buffer_size = 8096
    queue_depth = 1
    data_format = SENSOR_FORMAT_ISP_TUNING_REQUEST
    name = tuning_requests
end INTERIM_DATA_UNIT_1
begin ISP_TUNING_1
    request_interim_data_unit = INTERIM_DATA_UNIT_1
    sensor_units = SENSOR_UNIT_1
end ISP_TUNING_1
CONFEOF

echo ""
echo "=== Setup complete! ==="
echo ""
echo "IMPORTANT: If this is a Pi5, REBOOT NOW before running the app:"
echo "  reboot"
echo ""
echo "After reboot (or immediately on Pi4):"
echo "  ./build.sh          <- compile the app"
echo "  ./run.sh            <- run (currently symlinked to run_pi5_c920.sh)"
echo ""
echo "Available run scripts:"
echo "  ./run_pi4_picam.sh  <- Pi4 + Pi Camera Module 3"
echo "  ./run_pi4_c920.sh   <- Pi4 + Logitech C920 USB webcam"
echo "  ./run_pi5_c920.sh   <- Pi5 + Logitech C920 USB webcam"
echo ""
echo "To change active platform: ln -sf run_pi4_picam.sh run.sh"
