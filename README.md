# BOOPBOT

A Qt Quick application for QNX SDP 8.0, running on a Raspberry Pi 4B with a Pi Camera Module 3.
Built for CUHacking. Black/green terminal-themed UI with a live camera feed panel and API control buttons.

## Hardware / OS requirements

- Raspberry Pi 4B
- Raspberry Pi Camera Module 3 (imx708 sensor)
- QNX SDP 8.0 flashed and running on the Pi (aarch64le)
- Qt 6.10 built/installed natively on the QNX image (`/usr/lib/cmake/Qt6`)
- A Wayland session running on the target (Weston), accessible over TigerVNC for development

## Quick start

```sh
git clone git@github.com:anakafeel/QT_BOOPBOT.git
cd QT_BOOPBOT
./build.sh
./run.sh
```

`run.sh` restarts the QNX Sensor service with the correct camera config, sets the required
Wayland/Qt environment variables, and launches the app. `build.sh` just wraps the standard
`cmake` + `make` steps.

If you're connecting over VNC to a desktop session that doesn't already have the Wayland
env vars set system-wide, you'll need a terminal running inside that VNC session (e.g.
xfce4-terminal) to run these scripts, since `WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR` are
session-specific.

## Project layout

- `main.cpp` — app entry point, sets up the QML engine, the CameraWorker thread, and signal/slot wiring
- `Main.qml` — the UI (camera feed panel, system control buttons, API response box, camera status box)
- `camera_provider.h` / `camera_provider.cpp` — camera capture backend (`CameraWorker` class) and the `CameraImageProvider` that feeds frames into QML's `Image` element via `image://camera/frame`
- `camera_api.h` — **hand-reconstructed** QNX Camera API declarations (see Known Issues below — this image ships no real camera dev headers)
- `CMakeLists.txt` — links against Qt6, `camapi`, and `screen`

## Known issues (read this before debugging camera problems)

This QNX image does **not** ship real Camera API headers (`camera_api.h`) anywhere on the
filesystem — confirmed via a full `find / -iname camera_api.h` search. The header in this repo
is hand-reconstructed from QNX's online documentation, `nm -D` symbol dumps of
`/usr/lib/libcamapi.so`, and disassembly of the official `camera_example*` binaries
(`/usr/bin/camera_example3_viewfinder` etc., which are non-stripped). Some enum values in it
are still best-guesses; treat anything you haven't personally verified with suspicion.

Two distinct, confirmed bugs are blocking a working live camera feed on this exact hardware
combination (RPi4 + Camera Module 3 + Broadcom external sensor platform):

1. **Callback mode**: passing any real (non-null) callback function pointer to
   `camera_start_viewfinder()` causes `camera_attach_callback` to fail with
   `err=13 (Permission denied)` on the IPC layer, 100% reproducible, regardless of viewfinder
   mode or properties set. `nullptr` callback mode works fine in isolation.

2. **Stream mode** (the documented workaround for #1 — disable the auto window via
   `CAMERA_IMGPROP_CREATEWINDOW=0`, consume frames via Screen API `screen_acquire_buffer`
   instead of a callback): the camera genuinely starts and captures a real frame
   (confirmed via `slog2info` — full state machine transition to `VIDEOVF`, "received first
   preview frame from start of preview"), but ~60-90ms later camapi's own internal
   `stream_cleanup()` fails with `err=22` on both stream and context destroy, and the sensor
   service tears the viewfinder back down (`VIDEOVF -> CONNECTED -> DISCONNECTED`). This
   happens regardless of whether the app's own Screen context/window is created before or
   after `camera_open()` — i.e. it does not appear to be an application-code ordering bug,
   but something internal to camapi's stream-mode teardown path on this image.

QNX's own official release notes (qnxeverywhere/rel_notes.html) document a related, officially
acknowledged bug: **QNXE-1351** — running `camera_example2_events -u 1` with the Camera
Module 3 on a Raspberry Pi 4 results in a pulse error, no workaround listed. Both bugs found
here are consistent with (though not identical to) that same class of platform-level
instability in the Sensor Framework on this exact hardware/image combination.

The current `camera_provider.cpp` in this repo is in the **stream-mode (broken) state** — it
will compile and run, the camera will briefly connect, then drop out within ~100ms. See
`qt-qnx-setup-guideV3.md` (if present in your local notes — not yet committed to this repo)
for the full blow-by-blow debugging history and next steps to try.

### Suggested next steps for whoever picks this up
- Re-test `/usr/bin/camera_example3_viewfinder` directly (no boopbot involved) to confirm it
  still works cleanly on this image, and diff its approach against ours — it likely leaves
  `CAMERA_IMGPROP_CREATEWINDOW` at its default (1) rather than disabling it, letting camapi
  own the Screen window entirely, which may be the actually-stable code path here.
- If so, pivot to: callback-window mode (default window, no data callback), then poll the
  auto-created window's buffer via `screen_get_window_property_pv(SCREEN_PROPERTY_RENDER_BUFFERS)`
  on a `QTimer`, without ever creating a competing Screen context of our own.
- Consider filing/searching QNX support or Discord (https://discord.gg/Jj4EkkrFTT) referencing
  QNXE-1351 for both the `err=13` callback bug and the `err=22` stream_cleanup crash.

## Camera service setup (manual, if not using run.sh)

```sh
slay sensor 2>/dev/null
sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/camera_module3.conf &
sleep 3
ls /dev/sensor/   # should show camera1, data1
```

## Debugging tips

- `slog2info | grep -i camapi` — shows real camapi error chains, more detailed than what
  surfaces in the app's CAMERA STATUS panel
- `slog2info | tail -30` — shows sensor_service state machine transitions, useful for seeing
  exactly when/why the camera connection drops
- The CAMERA STATUS panel in the UI only shows the *first* status message reached before a
  failure; always cross-check `slog2info` for the full picture
