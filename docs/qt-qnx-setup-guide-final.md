# Qt on QNX SDP 8.0 - Complete Setup Guide

I wrote this to document everything I went through to get a Qt Quick app running on a Raspberry Pi 4B running QNX SDP 8.0, displayed over TigerVNC through Weston/Wayland. I went down a few dead ends before finding what actually worked, so I kept all of it in here so I don't repeat the same mistakes.

---

## My Environment

| Item | Value |
|---|---|
| Host OS | Fedora Linux |
| QNX SDP | QNX SDP 8.0 |
| QNX SDP path | `/home/anakafeel/qnx/SDP/qnx800_1` |
| Target hardware | Raspberry Pi 4B running QNX |
| Target architecture | `aarch64le` |
| Cross-compiled Qt (kept for reference) | Qt 6.11.0 - built fine but has an xdg-shell bug on QNX |
| Working Qt on target | System Qt 6.10.0 installed via `apk` |
| QNX target hostname | `anakafeelqnxpi.local` |
| QNX target user | `qnxuser` / `root` |
| Wayland socket | `/data/var/run/user/1000/wayland-1` |
| XDG_RUNTIME_DIR | `/data/var/run/user/1000` |
| VNC client | TigerVNC -> `anakafeelqnxpi.local:5900` |
| Working app path on target | `/data/home/qnxuser/qt_hello_sys/` |

The QNX target root filesystem `/` is not writable. Everything I put on the device lives under `/data/`.

---

## Links I Used

- Qt on QNX: https://doc.qt.io/qt-6/qnx.html
- Building Qt for QNX: https://doc.qt.io/qt-6/building-qt-for-qnx.html
- QNX target requirements: https://doc.qt.io/qt-6/qnx-target-requirements.html
- Qt source downloads: https://download.qt.io/official_releases/qt/
- QNX SDP 8.0 docs: https://www.qnx.com/developers/docs/8.0/com.qnx.doc.qnxsdp.nav/topic/bookset.html

---

# PART 1 - Cross-Compiling Qt 6.11 (Archive)

I started by trying to cross-compile Qt 6.11 from my Fedora host and push it to the device. I got pretty far with this approach but hit a Qt 6.11 bug on QNX SDP 8.0 that caused a permanent black screen on Wayland. I'm keeping these steps for reference in case I want to try again with a newer/fixed Qt version. If you just want the working setup, skip to Part 2.

---

## Step 1 - Prerequisites

### 1.1 QNX SDP

I had this installed already at `/home/anakafeel/qnx/SDP/qnx800_1`. I source this env script before doing anything cross-compile related:

```sh
/home/anakafeel/qnx/SDP/qnx800_1/qnxsdp-env.sh
```

### 1.2 Host Qt for Linux

I downloaded and ran the Qt Online Installer:

```sh
cd ~/Downloads
chmod +x qt-online-installer-linux-x64-4.11.0.run
./qt-online-installer-linux-x64-4.11.0.run
```

I installed it to `/home/anakafeel/Qt`. To verify it landed correctly:

```sh
find /home/anakafeel/Qt -path "*gcc_64/bin/qt-cmake" 2>/dev/null
# Expected: /home/anakafeel/Qt/6.11.0/gcc_64/bin/qt-cmake
```

The host Qt is needed for build-time tools like `moc`, `rcc`, and `qt-cmake` during cross-compilation.

### 1.3 Qt Source

I downloaded `qt-everywhere-src-6.11.0.tar.xz` from https://download.qt.io/official_releases/qt/6.11/6.11.0/single/ and extracted it:

```sh
cd /home/anakafeel
tar -xf /home/anakafeel/Downloads/qt-everywhere-src-6.11.0.tar.xz
ls /home/anakafeel/qt-everywhere-src-6.11.0/configure  # verify it extracted
```

---

## Step 2 - Confirm QNX SDP Environment

I ran this on my Fedora host before anything else to make sure the QNX toolchain was active:

```sh
source /home/anakafeel/qnx/SDP/qnx800_1/qnxsdp-env.sh

echo $QNX_HOST   # /home/anakafeel/qnx/SDP/qnx800_1/host/linux/x86_64
echo $QNX_TARGET # /home/anakafeel/qnx/SDP/qnx800_1/target/qnx
which q++        # /home/anakafeel/qnx/SDP/qnx800_1/host/linux/x86_64/usr/bin/q++
q++ -V           # Should show: 12.2.0,gcc_ntoaarch64le
```

If `q++ -V` shows `/usr/bin/c++` instead, the QNX env wasn't sourced and host GCC leaked in. Source the script again and check.

Correct output looks like:
```
QCC 12.2.0 / qcc / q++ / gcc_ntoaarch64le
```

---

## Step 3 - Create CMake Toolchain File

I created a toolchain file to tell CMake it's building for QNX aarch64le using `qcc`/`q++`:

```sh
mkdir -p /home/anakafeel/qnxprojects/toolchains

cat > /home/anakafeel/qnxprojects/toolchains/qnx-aarch64le.cmake <<'EOF'
set(CMAKE_SYSTEM_NAME QNX)
set(CMAKE_SYSTEM_PROCESSOR aarch64le)
set(CMAKE_SYSTEM_VERSION 800)

set(arch gcc_ntoaarch64le)

set(CMAKE_C_COMPILER qcc)
set(CMAKE_C_COMPILER_TARGET ${arch})

set(CMAKE_CXX_COMPILER q++)
set(CMAKE_CXX_COMPILER_TARGET ${arch})

set(CMAKE_SYSROOT $ENV{QNX_TARGET})

set(CMAKE_FIND_ROOT_PATH
    $ENV{QNX_TARGET}
    $ENV{QNX_TARGET}/aarch64le
)
EOF
```

---

## Step 4 - Clean Build Directory

I always build out-of-source. If I accidentally ran configure inside the source tree, I cleaned it first:

```sh
cd /home/anakafeel/qt-everywhere-src-6.11.0
rm -rf CMakeCache.txt CMakeFiles
rm -rf qtbase/CMakeCache.txt qtbase/CMakeFiles
```

Then set up a fresh build directory:

```sh
rm -rf /home/anakafeel/qt-build-qnx-aarch64le
mkdir -p /home/anakafeel/qt-build-qnx-aarch64le
cd /home/anakafeel/qt-build-qnx-aarch64le
source /home/anakafeel/qnx/SDP/qnx800_1/qnxsdp-env.sh
```

---

## Step 5 - Configure Qt for QNX

I ran this from `/home/anakafeel/qt-build-qnx-aarch64le`. Getting this configure command right took a while - I hit a lot of missing header errors that I had to disable one by one.

```sh
/home/anakafeel/qt-everywhere-src-6.11.0/configure \
  -release \
  -nomake tests \
  -nomake examples \
  -submodules qtbase,qtshadertools,qtdeclarative \
  -qt-host-path /home/anakafeel/Qt/6.11.0/gcc_64 \
  -prefix /qt \
  -extprefix /home/anakafeel/qt-qnx-aarch64le \
  -cmake-generator Ninja \
  -opengl es2 \
  -qt-freetype \
  -qt-harfbuzz \
  -no-fontconfig \
  -no-libpng \
  -no-libjpeg \
  -- \
  -DCMAKE_TOOLCHAIN_FILE=/home/anakafeel/qnxprojects/toolchains/qnx-aarch64le.cmake \
  -DCMAKE_SYSTEM_VERSION=800 \
  -DBUILD_qtimageformats=OFF \
  -DCMAKE_DISABLE_FIND_PACKAGE_LTTngUST=TRUE \
  -DCMAKE_DISABLE_FIND_PACKAGE_GSSAPI=TRUE \
  -DCMAKE_DISABLE_FIND_PACKAGE_Brotli=TRUE \
  -DCMAKE_DISABLE_FIND_PACKAGE_Harfbuzz=TRUE \
  -DCMAKE_DISABLE_FIND_PACKAGE_Freetype=TRUE \
  -DCMAKE_DISABLE_FIND_PACKAGE_PNG=TRUE \
  -DCMAKE_DISABLE_FIND_PACKAGE_JPEG=TRUE \
  -DCMAKE_DISABLE_FIND_PACKAGE_Libdrm=TRUE \
  -DCMAKE_DISABLE_FIND_PACKAGE_GBM=TRUE \
  -DQT_FEATURE_lttng=OFF \
  -DQT_FEATURE_tracepoints=OFF \
  -DQT_FEATURE_wayland=OFF \
  -DQT_FEATURE_wayland_client=OFF \
  -DQT_FEATURE_wayland_server=OFF \
  -DQT_FEATURE_glib=OFF \
  -DQT_FEATURE_pcre2=ON \
  -DQT_FEATURE_system_pcre2=OFF \
  -DQT_FEATURE_gssapi=OFF \
  -DQT_FEATURE_brotli=OFF \
  -DQT_FEATURE_png=OFF \
  -DQT_FEATURE_jpeg=OFF \
  -DQT_FEATURE_kms=OFF \
  -DQT_FEATURE_kms_support=OFF \
  -DQT_FEATURE_eglfs=OFF \
  -DQT_FEATURE_eglfs_kms=OFF \
  -DQT_FEATURE_eglfs_gbm=OFF \
  -DQT_FEATURE_libdrm=OFF \
  -DQT_FEATURE_gbm=OFF
```

### Why I used each flag

| Flag | Why |
|---|---|
| `-release` | Build release libraries |
| `-nomake tests` / `-nomake examples` | Skip stuff I don't need |
| `-submodules qtbase,qtshadertools,qtdeclarative` | Minimal Qt Quick build, nothing extra |
| `-qt-host-path` | Use Linux Qt tools during cross-compilation |
| `-prefix /qt` | Runtime prefix baked into Qt |
| `-extprefix` | Where Qt gets installed on the host for staging |
| `-cmake-generator Ninja` | Faster builds than Make |
| `-opengl es2` | Use OpenGL ES/EGL, not desktop OpenGL |
| `-qt-freetype` / `-qt-harfbuzz` | Use the bundled versions, not system ones |
| `-no-fontconfig` | Avoid pulling in Linux Fontconfig |
| `-no-libpng` / `-no-libjpeg` | These headers are missing in the QNX sysroot |
| `BUILD_qtimageformats=OFF` | Avoids WebP/TIFF dependency failures |
| `QT_FEATURE_system_pcre2=OFF` | Use bundled PCRE2 |
| `QT_FEATURE_glib=OFF` | Stops host GLib leaking in |
| `QT_FEATURE_kms/libdrm/gbm=OFF` | No Linux DRM/KMS on QNX |
| `QT_FEATURE_wayland*=OFF` | Avoid Wayland module deps during cross-compile |
| `QT_FEATURE_eglfs*=OFF` | No Linux EGLFS/GBM paths |

### Errors I hit and fixed with this config

| Error | Fix |
|---|---|
| `pcre2.h: No such file or directory` | `-DQT_FEATURE_system_pcre2=OFF` |
| `gssapi/gssapi.h: No such file or directory` | `-DQT_FEATURE_gssapi=OFF` |
| `brotli/decode.h: No such file or directory` | `-DQT_FEATURE_brotli=OFF` |
| `GL/gl.h: No such file or directory` | `-opengl es2` |
| `png.h: No such file or directory` | `-no-libpng`, `QT_FEATURE_png=OFF` |
| `xf86drm.h: No such file or directory` | `QT_FEATURE_kms=OFF`, `libdrm=OFF`, `gbm=OFF` |
| `jpeglib.h: No such file or directory` | `-no-libjpeg`, `QT_FEATURE_jpeg=OFF` |
| `webp/decode.h: No such file or directory` | `BUILD_qtimageformats=OFF` |

### Checking the configure summary

```sh
grep -i "opengl\|egl\|freetype\|harfbuzz\|fontconfig\|pcre\|glib\|gss\|brotli\|jpeg\|png\|kms\|drm\|gbm\|imageformats" \
  /home/anakafeel/qt-build-qnx-aarch64le/config.summary
```

What I was looking for:
```
Desktop OpenGL ....................... no
OpenGL ES 2.0 ........................ yes
EGL .................................. yes
FreeType ............................. yes
Using system FreeType ................ no
HarfBuzz ............................. yes
Using system HarfBuzz ................ no
Fontconfig ........................... no
pcre2 ................................ yes
system_pcre2 ......................... no
glib ................................. no
```

---

## Step 6 - Build and Install Qt

```sh
cd /home/anakafeel/qt-build-qnx-aarch64le
cmake --build . --parallel 4
cmake --install .
```

When it finished successfully, the last line looked like:
```
[5231/5231] Linking CXX executable qtbase/bin/qmleasing
```

I verified the install:

```sh
ls /home/anakafeel/qt-qnx-aarch64le/bin/qt-cmake
ls /home/anakafeel/qt-qnx-aarch64le/lib/libQt6Core.so*
ls /home/anakafeel/qt-qnx-aarch64le/plugins/platforms  # should include libqqnx.so
```

---

## Step 7 - Deploy Qt Runtime to the Device

```sh
scp -r /home/anakafeel/qt-qnx-aarch64le qnxuser@anakafeelqnxpi.local:/data/home/qnxuser/qt
```

Note: I tried putting it at `/qt` first. That doesn't work - the root filesystem is read-only. Has to go under `/data/`.

I checked it landed correctly on the target:

```sh
ls /data/home/qnxuser/qt/plugins/platforms
# Expected: libqminimal.so  libqoffscreen.so  libqqnx.so  libqvkkhrdisplay.so  libqvnc.so
ls /data/home/qnxuser/qt/qml
```

---

## Step 8 - Add Fonts

Qt doesn't bundle fonts anymore. Without them I got:
```
QFontDatabase: Cannot find font directory /data/home/qnxuser/qt/lib/fonts.
```

I grabbed DejaVu from my host and pushed it over:

```sh
mkdir -p /tmp/qnx-fonts
cp /usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf /tmp/qnx-fonts/ 2>/dev/null || true
cp /usr/share/fonts/dejavu/DejaVuSans.ttf /tmp/qnx-fonts/ 2>/dev/null || true

scp -r /tmp/qnx-fonts qnxuser@anakafeelqnxpi.local:/data/home/qnxuser/qt/lib/fonts
```

---

## Step 9 - Create a Minimal Qt Quick App (Cross-Compiled)

I created this on my Fedora host:

```sh
mkdir -p /home/anakafeel/qnxprojects/qt_hello
cd /home/anakafeel/qnxprojects/qt_hello
```

### `main.cpp`

I used direct file loading here. I tried `engine.loadFromModule("QtHello", "Main")` first but that threw `QtHello module contains no type named "Main"` on the target. Direct loading works:

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QCoreApplication>
#include <QUrl>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    const QUrl url = QUrl::fromLocalFile(
        QCoreApplication::applicationDirPath() + "/Main.qml"
    );
    engine.load(url);

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
```

### `Main.qml`

```qml
import QtQuick
import QtQuick.Window

Window {
    width: 800
    height: 480
    visible: true
    color: "red"
    title: "BOOPBOT"

    Text {
        anchors.centerIn: parent
        text: "BOOPBOT LIVES"
        color: "white"
        font.pixelSize: 52
        font.bold: true
    }
}
```

### `CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.21)
project(qt_hello LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_add_executable(qt_hello main.cpp)
target_link_libraries(qt_hello PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)
```

---

## Step 10 - Build and Deploy the App (Cross-Compiled)

```sh
source /home/anakafeel/qnx/SDP/qnx800_1/qnxsdp-env.sh
cd /home/anakafeel/qnxprojects/qt_hello
rm -rf build-qnx

/home/anakafeel/qt-qnx-aarch64le/bin/qt-cmake \
  -S . -B build-qnx -DCMAKE_BUILD_TYPE=Debug

cmake --build build-qnx --parallel 4

scp build-qnx/qt_hello qnxuser@anakafeelqnxpi.local:/data/home/qnxuser/tmp/qt_hello
scp Main.qml qnxuser@anakafeelqnxpi.local:/data/home/qnxuser/tmp/Main.qml
```

---

## Step 11 - Run on QNX Target (Cross-Compiled Qt)

```sh
export QT_ROOT=/data/home/qnxuser/qt
export LD_LIBRARY_PATH=$QT_ROOT/lib:$LD_LIBRARY_PATH
export QT_PLUGIN_PATH=$QT_ROOT/plugins
export QML2_IMPORT_PATH=$QT_ROOT/qml
export QML_IMPORT_PATH=$QT_ROOT/qml
export QT_QPA_PLATFORM=qnx
export QT_FORCE_STDERR_LOGGING=1
export QT_QPA_FONTDIR=$QT_ROOT/lib/fonts

chmod +x /data/home/qnxuser/tmp/qt_hello
cd /data/home/qnxuser/tmp
./qt_hello
```

---

## What Went Wrong - The Full Debugging Story

This is the part I want to remember. I hit four separate issues before getting anything on screen.

### Issue 1 - App killed by Weston/fullscreen-winmgr

When I ran with `QT_QPA_PLATFORM=qnx` the app launched and immediately got a `software termination signal`. The screen stayed black.

What was happening: Weston was running fullscreen and owning the display. My app tried to create a competing fullscreen surface and got killed by `fullscreen-winmgr`.

I checked what was running with:
```sh
pidin arg | grep -E "screen|winmgr|demo|weston|vnc"
```

Fix: switch to `QT_QPA_PLATFORM=wayland` or `vnc` instead of `qnx`.

### Issue 2 - Wayland plugin not in the build

When I tried `QT_QPA_PLATFORM=wayland` I got:
```
Could not find the Qt platform plugin "wayland"
Available platform plugins are: minimal, offscreen, qnx, vnc, vkkhrdisplay.
```

I had built Qt with `-DQT_FEATURE_wayland=OFF` so the wayland plugin simply wasn't there. Fix: use VNC platform for now, or rebuild with Wayland enabled.

### Issue 3 - VNC: `Cannot handle 0 bpp client`

I switched to `QT_QPA_PLATFORM=vnc:port=5901`. The VNC server started but every client connection got a black screen and the log spammed `Cannot handle 0 bpp client`.

This one took a while to figure out. The root cause: I built Qt with `-opengl es2`. The VNC platform plugin uses `QFbScreen`, a software framebuffer compositor. With OpenGL ES only and no software rasterizer, `QFbScreen::initDevice()` can't allocate the framebuffer, so `depth()` returns 0 and every VNC client gets rejected.

Fix: rebuild Qt with `-opengl no` and add `-DQT_FEATURE_opengl=OFF -DQT_FEATURE_opengles2=OFF -DQT_FEATURE_egl=OFF`. That forces the software rasterizer and `QFbScreen` initializes correctly.

### Issue 4 - xdg-shell initial commit deadlock (the actual killer)

Even after fixing the VNC issue, running via Wayland gave a black screen and silent exit. I turned on `WAYLAND_DEBUG=1` and compared the protocol log against `weston-flowers` (which works fine):

```
weston-flowers (works):
-> wl_compositor.create_surface
-> xdg_wm_base.get_xdg_surface
-> xdg_surface.get_toplevel
-> wl_surface.commit()          <- initial commit BEFORE configure
<- xdg_toplevel.configure(0, 0) <- Weston sends configure in response
<- xdg_surface.configure(120)
-> xdg_surface.ack_configure(120)
-> wl_shm_pool + wl_surface.attach + wl_surface.commit  <- renders

My Qt 6.11 app (broken):
-> wl_compositor.create_surface
-> xdg_wm_base.get_xdg_surface
-> xdg_surface.get_toplevel
-> xdg_toplevel.set_maximized()
-> xdg_toplevel.set_title("BOOPBOT")
<- STOPS HERE, never sends wl_surface.commit()
```

Qt 6.11's Wayland client doesn't send the initial `wl_surface.commit()` before waiting for Weston's `configure` event. Weston never sends `configure` without a commit first. So they both sit there waiting for the other - permanent deadlock, silent exit. This is a Qt 6.11 xdg-shell regression that shows up specifically with QNX SDP 8.0's Weston build.

I verified that the system Qt 6.10.0 on the device (installed via `apk`) does NOT have this bug by running `FxMaterialShowroomApp` and checking its Wayland log. It does the initial commit correctly before waiting for configure.

That's when I stopped trying to fix the cross-compiled Qt and switched to building natively on the device using the system Qt. That's Part 2.

---

# PART 2 - What Actually Works (System Qt 6.10 + Native Build)

I build directly on the QNX target using the system Qt 6.10.0 that's already installed via `apk`. No cross-compilation, no deployment headaches. This is what I use now.

---

## Step 1 - Connect to the Device

SSH:
```sh
ssh root@anakafeelqnxpi.local
```

TigerVNC (to see the display):
```
anakafeelqnxpi.local:5900
```

---

## Step 2 - Check System Qt is There

```sh
apk list --installed | grep qt6-base
# Expected: qt6-base-6.10.0-r1 aarch64 [installed]

find /usr/lib/cmake/Qt6 -name "Qt6Config.cmake"
# Expected: /usr/lib/cmake/Qt6/Qt6Config.cmake
```

If Qt base is missing for some reason:
```sh
apk add qt6-base qt6-base-dev qt6-declarative qt6-declarative-dev qt6-wayland
```

---

## Step 3 - Find the Wayland Socket

The Wayland socket is not where I expected. I found it by running:

```sh
find / -name "wayland-*" -type s 2>/dev/null
# Returns: /data/var/run/user/1000/wayland-1
```

So I need these two env vars set:
```sh
export XDG_RUNTIME_DIR=/data/var/run/user/1000
export WAYLAND_DISPLAY=wayland-1
```

---

## Step 4 - Create the App on Target

```sh
mkdir -p /data/home/qnxuser/myapp
cd /data/home/qnxuser/myapp
```

`main.cpp`:
```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QUrl>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.load(QUrl::fromLocalFile(
        QCoreApplication::applicationDirPath() + "/Main.qml"
    ));
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}
```

`Main.qml`:
```qml
import QtQuick
import QtQuick.Window

Window {
    width: 800
    height: 600
    visible: true
    color: "red"
    title: "BOOPBOT"

    Text {
        anchors.centerIn: parent
        text: "BOOPBOT LIVES"
        color: "white"
        font.pixelSize: 40
        font.bold: true
    }
}
```

`CMakeLists.txt`:
```cmake
cmake_minimum_required(VERSION 3.16)
project(myapp)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)
qt_add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)
```

---

## Step 5 - Build on Target

```sh
cd /data/home/qnxuser/myapp

cmake . -DCMAKE_PREFIX_PATH=/usr/lib/cmake/Qt6 -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -5

make -j4 2>&1 | tail -10
```

cmake output I expect to see (last 5 lines):
```
-- Configuring done (82.2s)
-- Generating done (0.2s)
-- Build files have been written to: /data/home/qnxuser/myapp
```

make output I expect:
```
[-100%] Building CXX object CMakeFiles/myapp.dir/main.cpp.o
[-100%] Linking CXX executable myapp
[-100%] Built target myapp
```

First cmake configure takes about 80 seconds on the RPi 4B. After that incremental builds are fast. I use `| tail` to keep the output readable but I drop it if I need to see errors.

---

## Step 6 - Run on Target

I launch from xfce4-terminal on the VNC desktop, not from an SSH session. If I launch over SSH the Wayland env vars aren't set and it fails to find the display.

```sh
export XDG_RUNTIME_DIR=/data/var/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export QT_QPA_PLATFORM=wayland
export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH

cd /data/home/qnxuser/myapp
./myapp
```

To make these permanent so I don't have to set them every time:
```sh
echo 'export XDG_RUNTIME_DIR=/data/var/run/user/1000' >> ~/.profile
echo 'export WAYLAND_DISPLAY=wayland-1' >> ~/.profile
echo 'export QT_QPA_PLATFORM=wayland' >> ~/.profile
```

---

## Adding More Qt Modules

The system Qt 6.10 modules are all installable via `apk`:

```sh
apk list --available | grep qt6   # see what's available

apk add qt6-multimedia
apk add qt6-charts
apk add qt6-quick3d qt6-quick3d-dev
apk add qt6-svg
apk add qt6-websockets
```

Then I update `CMakeLists.txt` to pull them in:
```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Multimedia)
target_link_libraries(myapp PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Multimedia)
```

---

# PART 3 - My Dev Workflow

## VSCode + QNX Toolkit + Remote SSH

The cleanest setup I found: use VSCode's Remote SSH extension to edit files directly on the target, then build from the integrated terminal. No SCP needed in the edit loop.

### Extensions I use

- QNX Toolkit (already installed)
- Remote - SSH (`ms-vscode-remote.remote-ssh`)
- C/C++ (`ms-vscode.cpptools`)
- CMake Tools (`ms-vscode.cmake-tools`)

### Connecting VSCode to the device

1. `Ctrl+Shift+P` -> `Remote-SSH: Add New SSH Host`
2. Enter `ssh root@anakafeelqnxpi.local`
3. `Ctrl+Shift+P` -> `Remote-SSH: Connect to Host` -> pick `anakafeelqnxpi.local`
4. Open folder `/data/home/qnxuser/myapp`

VSCode installs its server on the device and I get full IntelliSense, the file explorer, and a terminal all running natively on QNX.

### IntelliSense config

I put this in `.vscode/c_cpp_properties.json`:
```json
{
  "configurations": [
    {
      "name": "QNX-aarch64",
      "includePath": [
        "/usr/include/qt6",
        "/usr/include/qt6/QtCore",
        "/usr/include/qt6/QtGui",
        "/usr/include/qt6/QtQml",
        "/usr/include/qt6/QtQuick",
        "${workspaceFolder}/**"
      ],
      "defines": [],
      "compilerPath": "/usr/bin/c++",
      "cppStandard": "c++17",
      "intelliSenseMode": "clang-x64"
    }
  ],
  "version": 4
}
```

### CMake Tools config

I put this in `.vscode/settings.json`:
```json
{
  "cmake.configureArgs": [
    "-DCMAKE_PREFIX_PATH=/usr/lib/cmake/Qt6",
    "-DCMAKE_BUILD_TYPE=Debug"
  ],
  "cmake.buildDirectory": "${workspaceFolder}/build"
}
```

Then `Ctrl+Shift+P` -> `CMake: Configure` and `CMake: Build` just work.

---

## SCP Workflow (when editing on Fedora host)

If I'm working on my Fedora machine and want to push to the device:

```sh
# Push one file
scp Main.qml root@anakafeelqnxpi.local:/data/home/qnxuser/myapp/

# Push the whole project
scp -r /home/anakafeel/qnxprojects/myapp \
    root@anakafeelqnxpi.local:/data/home/qnxuser/myapp

# Build remotely over SSH
ssh root@anakafeelqnxpi.local \
  "cd /data/home/qnxuser/myapp && make -j4"

# Push + build + run in one shot
scp -r . root@anakafeelqnxpi.local:/data/home/qnxuser/myapp && \
ssh root@anakafeelqnxpi.local \
  "cd /data/home/qnxuser/myapp && make -j4 && \
   XDG_RUNTIME_DIR=/data/var/run/user/1000 \
   WAYLAND_DISPLAY=wayland-1 \
   QT_QPA_PLATFORM=wayland \
   ./myapp &"
```

---

## GitHub Workflow

### First time setup on Fedora host

```sh
cd /home/anakafeel/qnxprojects/myapp
git init
git remote add origin https://github.com/yourusername/myapp.git
```

`.gitignore`:
```
build/
build-qnx/
*.o
CMakeCache.txt
CMakeFiles/
cmake_install.cmake
Makefile
myapp
qt_hello_sys
```

First push:
```sh
git add CMakeLists.txt main.cpp Main.qml .gitignore .vscode/
git commit -m "Initial Qt Quick app for QNX SDP 8.0"
git push -u origin main
```

### Day to day

```sh
git add -A
git commit -m "feat: add sensor readout widget"
git push
```

### Pulling and building on the device

```sh
# First time
apk add git
cd /data/home/qnxuser
git clone https://github.com/yourusername/myapp.git
cd myapp
cmake . -DCMAKE_PREFIX_PATH=/usr/lib/cmake/Qt6 -DCMAKE_BUILD_TYPE=Release
make -j4

# After that
git pull
make -j4
```

---

# PART 4 - Reference

## Env Vars I Always Need

```sh
export XDG_RUNTIME_DIR=/data/var/run/user/1000   # where the Wayland socket lives
export WAYLAND_DISPLAY=wayland-1                  # Wayland socket name
export QT_QPA_PLATFORM=wayland                    # tell Qt to use Wayland
export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH  # system Qt libs
```

Debug vars when something goes wrong:
```sh
export WAYLAND_DEBUG=1                          # logs all Wayland protocol messages
export QT_DEBUG_PLUGINS=1                       # Qt plugin loading
export QT_LOGGING_RULES="qt.qpa.*=true"         # Qt platform debug
export QT_FORCE_STDERR_LOGGING=1                # force Qt logs to stderr
```

---

## Errors I Hit and How I Fixed Them

| What I saw | Why it happened | What fixed it |
|---|---|---|
| `Failed to create wl_display` | `XDG_RUNTIME_DIR` wasn't set | `export XDG_RUNTIME_DIR=/data/var/run/user/1000` |
| `Could not load Qt platform plugin "wayland"` | Wrong `LD_LIBRARY_PATH` or launched from SSH instead of desktop terminal | Set `LD_LIBRARY_PATH=/usr/lib`; launch from xfce4-terminal on VNC |
| Black screen, silent exit on Wayland | xdg-shell initial commit bug in Qt 6.11 on QNX | Use system Qt 6.10 via `apk` |
| `Cannot handle 0 bpp client` on VNC | Qt built with `-opengl es2`, no software rasterizer | Use system Qt 6.10; or rebuild cross-compiled Qt with `-opengl no` |
| `software termination signal` | Weston owns the QNX Screen; my app tried to open it too | Use `QT_QPA_PLATFORM=wayland` not `qnx` |
| `Module "X" contains no type named "Main"` | Used `engine.loadFromModule()` which can't find QML on target | Use `QUrl::fromLocalFile(applicationDirPath() + "/Main.qml")` and keep the QML file next to the binary |
| CMake configure takes 80+ seconds | Normal on the RPi 4B | Just wait - incremental builds after that are fast |
| `ps: cannot execute` during cmake | QNX doesn't have `ps` | Harmless, ignore it |
| `libQt6Core.so missing` | Wrong `LD_LIBRARY_PATH` | `export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH` |
| App can't find QML files | QML file not next to the binary | Keep `Main.qml` in the same folder as the binary |

---

## Useful Debug Commands

```sh
# Find the Wayland socket
find / -name "wayland-*" -type s 2>/dev/null

# See what compositor processes are running
pidin arg | grep -E "screen|winmgr|demo|weston|vnc"

# Check the system Qt is where I expect
ls /usr/lib/libQt6Core.so*
ls /usr/lib/cmake/Qt6/Qt6Config.cmake
find /usr/lib -name "libqwayland*.so" 2>/dev/null

# Check my app binary
file /data/home/qnxuser/myapp/myapp
ldd /data/home/qnxuser/myapp/myapp

# Trace Wayland protocol messages
WAYLAND_DEBUG=1 ./myapp 2>&1 | tee /tmp/wayland.log
grep "wl_surface.*commit\|xdg.*configure\|ack_configure" /tmp/wayland.log | head -20
```

---

## Status

| Thing | Status |
|---|---|
| QNX SDP 8.0 on Fedora host | Working |
| QNX target (RPi 4B) via SSH | Working |
| TigerVNC to QNX xfce4 desktop | Working |
| Weston compositor on target | Working |
| System Qt 6.10.0 on target via apk | Working |
| Qt Quick app builds natively on target | Working |
| Qt Quick app renders on Wayland via VNC | Working - BOOPBOT LIVES |
| VSCode Remote SSH workflow | Ready |
| Cross-compiled Qt 6.11 VNC platform | Works after rebuilding with `-opengl no` |
| Cross-compiled Qt 6.11 Wayland | Broken - xdg-shell initial commit bug on QNX SDP 8.0 |


---

# PART 5 - Camera Feed in the Boopbot Qt App

After getting the Qt Quick UI working on Wayland, the next goal was adding a live camera feed to the boopbot app. This section documents everything I tried, what failed and why, and what the path forward is.

---

## What Was Already Installed

Before touching the camera, I checked what was available on the target:

```sh
apk list --available | grep -iE "uvc|video|camera|media"
```

Key finds:

- `qt6-multimedia-6.10.0-r0` -- Qt Multimedia available via apk (Qt's own docs say it can't be compiled for QNX SDP 8.0, but QNX built it themselves for this RPi4 image)
- `qt6-multimedia-gstreamer-6.10.0-r0` -- GStreamer backend
- `qt6-multimedia-ffmpeg-6.10.0-r0` -- FFmpeg backend
- `libopencv_videoio-4.12.0-r0` -- OpenCV video IO

I installed them:

```sh
apk add qt6-multimedia qt6-multimedia-dev qt6-multimedia-gstreamer
apk add libopencv_video libopencv_videoio
```

The QNX camera API was already present:

```sh
ls /usr/bin/camera_example*
# camera_example1_callback  camera_example2_events  camera_example3_viewfinder
# camera_example4_record    camera_example5_video_group  camera_example6_egl_viewfinder

ls /usr/lib/libcamapi*
# /usr/lib/libcamapi.so  /usr/lib/libcamapi.so.1
# /usr/lib/libcamapi_video.so  /usr/lib/libcamapi_video.so.1
```

GStreamer was installed with many plugins but no `libgstv4l2.so` -- no V4L2 source plugin. There's `libgstcamerabin.so` but no direct USB camera GStreamer source.

---

## Camera Hardware

I plugged in a UGREEN Camera 4K (USB VID/PID: 0xeba4:0x6579). The USB stack recognized it immediately:

```sh
usb -v
# Vendor: 0xeba4 (Image+)
# Product: 0x6579 (UGREEN Camera 4K)
```

The QNX camera API also detected it:

```sh
camera_example1_callback
# Available camera units:
#   CAMERA_UNIT_1 (specify -u 1)
```

Running `camera_example1_callback -u 1` printed real channel averages confirming frames were being read from the camera. The camera itself works at the hardware level.

---

## Qt Multimedia Test

I built a minimal test to check if Qt Multimedia could enumerate the camera:

```sh
mkdir -p /data/home/qnxuser/test_cam && cd /data/home/qnxuser/test_cam
```

`main.cpp`:
```cpp
#include <QCoreApplication>
#include <QMediaDevices>
#include <QCameraDevice>
#include <QDebug>
int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    auto cameras = QMediaDevices::videoInputs();
    qDebug() << "Found" << cameras.size() << "cameras";
    for (auto &c : cameras) qDebug() << c.description();
    return 0;
}
```

`CMakeLists.txt`:
```cmake
cmake_minimum_required(VERSION 3.16)
project(test_cam)
find_package(Qt6 REQUIRED COMPONENTS Core Multimedia)
qt_add_executable(test_cam main.cpp)
target_link_libraries(test_cam PRIVATE Qt6::Core Qt6::Multimedia)
```

```sh
cmake . -DCMAKE_PREFIX_PATH=/usr/lib/cmake/Qt6 -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -3
make -j4 2>&1 | tail -5

XDG_RUNTIME_DIR=/data/var/run/user/1000 WAYLAND_DISPLAY=wayland-1 \
QT_QPA_PLATFORM=wayland LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH \
./test_cam
```

Output:
```
qt.multimedia.gstreamer: Using Qt multimedia with GStreamer version: "GStreamer 1.26.8"
Found 0 cameras
```

Qt Multimedia with GStreamer is working but finds 0 cameras. GStreamer has no V4L2 source and no `/dev/video0` exists. The camera is only accessible through the QNX Camera API via the sensor service, not through V4L2.

---

## The Boopbot Qt App (UI Working)

The Qt Quick app builds and runs with a black/green CUHacking terminal aesthetic. Camera feed area shows `[ NO SIGNAL ]` pulsing until frames arrive. Five API buttons on the right flash the response panel on click. Status bar shows QNX SDP 8.0, RPi4B, Qt 6.10, Wayland, and CUHacking 2025.

### Project structure

```
/data/home/qnxuser/boopbot/
  main.cpp
  camera_provider.h
  camera_provider.cpp
  camera_api.h          (reconstructed manually -- see below)
  Main.qml
  CMakeLists.txt
```

### Build

```sh
cd /data/home/qnxuser/boopbot
cmake . -DCMAKE_PREFIX_PATH=/usr/lib/cmake/Qt6 -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -5
make -j4 2>&1 | tail -10
```

### Run

From xfce4-terminal on VNC:

```sh
export XDG_RUNTIME_DIR=/data/var/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export QT_QPA_PLATFORM=wayland
export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH
cd /data/home/qnxuser/boopbot
./boopbot
```

### Architecture

- `CameraWorker` -- QObject on a background thread, opens CAMERA_UNIT_1 via libcamapi, calls camera_start_viewfinder with a callback, converts frames to QImage
- `CameraRelay` -- QObject on the main thread that bridges signals from the worker thread to QML via Qt::QueuedConnection (needed because QML can't connect directly to objects on other threads)
- `CameraImageProvider` -- QQuickImageProvider that returns the latest frame when QML requests `image://camera/frame`

### Key build fixes I hit

`Q_OBJECT` moc generation wasn't running -- fixed by adding `set(CMAKE_AUTOMOC ON)` to CMakeLists.txt.

`camera_api.h` doesn't exist on the target -- reconstructed from `nm -D /usr/lib/libcamapi.so` and QNX docs. Key finding: the public function is `camera_private_set_vf_property`, not `camera_set_vf_property`.

Thread safety -- exposing `CameraWorker` directly to QML caused:
```
QQmlEngine: Illegal attempt to connect to CameraWorker that is in a different thread
abort (core dumped)
```
Fix: use `CameraRelay` as a proxy object that lives on the main thread and forwards signals via `Qt::QueuedConnection`.

---

## Reconstructed camera_api.h

The header is not installed on the target. Create it manually:

```sh
cat > /data/home/qnxuser/boopbot/camera_api.h << 'EOF'
#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef int camera_handle_t;
#define CAMERA_HANDLE_INVALID (-1)
typedef enum { CAMERA_UNIT_NONE=-1, CAMERA_UNIT_1=1, CAMERA_UNIT_2=2 } camera_unit_t;
#define CAMERA_MODE_RW   0x00000003
#define CAMERA_MODE_ROLL 0x00000010
typedef enum {
    CAMERA_EOK=0, CAMERA_EAGAIN=1, CAMERA_EINVAL=2, CAMERA_ENODEV=3,
    CAMERA_EMFILE=4, CAMERA_EBADF=5, CAMERA_EACCESS=6, CAMERA_ENODATA=7,
    CAMERA_ENOENT=8, CAMERA_ENOMEM=9, CAMERA_EOPNOTSUPP=10, CAMERA_ETIMEDOUT=11,
    CAMERA_EALREADY=12, CAMERA_EBUSY=13, CAMERA_ENOSPC=14, CAMERA_EUNINIT=15,
    CAMERA_EOPERR=16, CAMERA_EIOERR=17, CAMERA_ENOSYS=18, CAMERA_EPERM=19,
    CAMERA_ENOTSUP=20
} camera_error_t;
typedef enum { CAMERA_VFMODE_DEFAULT=0, CAMERA_VFMODE_VIDEO=1, CAMERA_VFMODE_PHOTO=2 } camera_vfmode_t;
typedef enum {
    CAMERA_FRAMETYPE_UNSPECIFIED=0, CAMERA_FRAMETYPE_NV12=1,
    CAMERA_FRAMETYPE_RGB8888=2, CAMERA_FRAMETYPE_RGB888=3, CAMERA_FRAMETYPE_GRAY8=4,
    CAMERA_FRAMETYPE_BAYER=6, CAMERA_FRAMETYPE_CBYCRY=7,
    CAMERA_FRAMETYPE_COMPRESSEDVIDEO=8, CAMERA_FRAMETYPE_COMPRESSEDAUDIO=9,
    CAMERA_FRAMETYPE_RGB565=10, CAMERA_FRAMETYPE_YCBCR420P=11,
    CAMERA_FRAMETYPE_YCBYCR=12, CAMERA_FRAMETYPE_YCRYCB=13, CAMERA_FRAMETYPE_CRYCBY=14
} camera_frametype_t;
typedef enum {
    CAMERA_IMGPROP_END=0, CAMERA_IMGPROP_WIDTH=1, CAMERA_IMGPROP_HEIGHT=2,
    CAMERA_IMGPROP_FORMAT=3, CAMERA_IMGPROP_FRAMERATE=4, CAMERA_IMGPROP_ROTATION=5,
    CAMERA_IMGPROP_CREATEWINDOW=11, CAMERA_IMGPROP_STRIDE=14
} camera_imgprop_t;
typedef enum {
    CAMERA_STATUS_UNKNOWN=0, CAMERA_STATUS_FOCUS_CHANGE=1,
    CAMERA_STATUS_POWERDOWN=2, CAMERA_STATUS_RESOURCENOTAVAIL=3
} camera_devstatus_t;
typedef struct { int width; int height; int stride; } camera_frame_nv12_t;
typedef struct { int width; int height; int stride; } camera_frame_rgb8888_t;
typedef struct { int width; int height; int stride; } camera_frame_rgb888_t;
typedef struct { int width; int height; int stride; } camera_frame_gray8_t;
typedef struct { int width; int height; int stride; } camera_frame_rgb565_t;
typedef struct { int width; int height; int stride; } camera_frame_ycbcr420p_t;
typedef struct { int width; int height; int stride; } camera_frame_ycbycr_t;
typedef struct { int width; int height; int stride; } camera_frame_ycrycb_t;
typedef struct { int width; int height; int stride; } camera_frame_crycby_t;
typedef struct { int width; int height; int stride; } camera_frame_unspecified_t;
typedef struct { int width; int height; int stride; } camera_frame_bayer_t;
typedef struct { int width; int height; int stride; } camera_frame_cbycry_t;
typedef struct { uint64_t bufsize; } camera_frame_compressedvideo_t;
typedef struct { uint64_t bufsize; } camera_frame_compressedaudio_t;
typedef struct { int width; int height; } camera_frame_roi_t;
typedef union {
    camera_frame_unspecified_t unspecified; camera_frame_nv12_t nv12;
    camera_frame_rgb8888_t rgb8888; camera_frame_rgb888_t rgb888;
    camera_frame_gray8_t gray8; camera_frame_bayer_t bayer;
    camera_frame_cbycry_t cbycry; camera_frame_compressedvideo_t compvid;
    camera_frame_compressedaudio_t compaud; camera_frame_rgb565_t rgb565;
    camera_frame_ycbcr420p_t ycbcr420p; camera_frame_ycbycr_t ycbycr;
    camera_frame_ycrycb_t ycrycb; camera_frame_crycby_t crycby;
    camera_frame_roi_t roi; camera_frame_nv12_t nv16;
} camera_framedesc_t;
typedef struct camera_buffer_t {
    camera_frametype_t frametype; uint64_t framesize; uint8_t* framebuf;
    uint64_t framemetasize; void* framemeta; int64_t frametimestamp;
    int32_t frameorientation; camera_framedesc_t framedesc;
} camera_buffer_t;
typedef void (*camera_vf_callback_t)(camera_handle_t, camera_buffer_t*, void*);
typedef void (*camera_status_callback_t)(camera_handle_t, camera_devstatus_t, uint16_t, void*);
camera_error_t camera_open(camera_unit_t unit, uint32_t mode, camera_handle_t* handle);
camera_error_t camera_close(camera_handle_t handle);
camera_error_t camera_set_vf_mode(camera_handle_t handle, camera_vfmode_t mode);
camera_error_t camera_private_set_vf_property(camera_handle_t handle, ...);
camera_error_t camera_private_get_vf_property(camera_handle_t handle, ...);
camera_error_t camera_start_viewfinder(camera_handle_t handle,
    camera_vf_callback_t vf_cb, camera_status_callback_t status_cb, void* arg);
camera_error_t camera_stop_viewfinder(camera_handle_t handle);
camera_error_t camera_get_supported_cameras(uint32_t numasked,
    uint32_t* numsupported, camera_unit_t* cameras);
#ifdef __cplusplus
}
#endif
EOF
```

---

## Camera Debugging - What I Learned

### The sensor service controls camera access

The camera cannot be opened directly with `camera_open` from a regular process. The sensor service must be running and have initialized the camera first. The sensor service creates `/dev/sensor/camera1` which is how the camera library knows the camera is ready.

### How the sensor service starts

In `/usr/etc/startup/post_startup.sh`, the sensor service only starts if `/dev/screen` exists (i.e. the Screen compositor is running). The default config runs the simulator camera:

```sh
# line 142 in post_startup.sh:
sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/sensor_demo.conf
waitfor /dev/sensor/camera1
```

To switch to USB camera, this line must be changed. I edited it:

```sh
sed -i 's|sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/sensor_demo.conf|#sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/sensor_demo.conf\n    sensor -U 521:521 -r /data/share/sensor -c /system/etc/config/sensor/usb_camera.conf|' /usr/etc/startup/post_startup.sh
```

### The USB camera sensor config

```sh
cat /system/etc/config/sensor/usb_camera.conf
# begin SENSOR_UNIT_1
#     type = usb_camera
#     name = front-camera
#     position = 0, 0, 0
#     direction = 0, 0, 0
#     default_video_framerate = 30
#     address = /dev/usb/io-usb-otg, -1, -1, -1, -1
# end SENSOR_UNIT_1
```

### Why USB camera fails - root cause

When running `sensor -U 521:521 -r /data/share/sensor -c /system/etc/config/sensor/usb_camera.conf`, slog2 shows:

```
static Platform* Platform::getPlatform()(98): Generic platform chosen
Did not find supported data units in config file
TIMEOUT waiting for Platform::getPlatform
```

When running with `SENSOR_GLOBAL` specifying `libsensor_platform_broadcom.so`:

```
Open platform successfully: variant PLATFORM_VARIANT_BCM2711 max unit 1
openExternalCamera successfully: input 0
Did not find supported data units in config file
TIMEOUT waiting for Platform::getPlatform
```

The broadcom platform library (`libsensor_platform_broadcom.so`) calls `getFrametypesPv` which queries the camera for supported pixel formats via the VCHIQ firmware interface. This interface was designed for the Raspberry Pi Camera Module (CSI connection) and does not properly enumerate UVC USB cameras. The call hangs and times out after 20 seconds.

### Configurations I tried

All of these were tried in various combinations. None produced a working `/dev/sensor/camera1`:

```sh
# Attempt 1: bare USB camera, no platform
sensor -U 521:521 -r /data/share/sensor \
  -c /system/etc/config/sensor/usb_camera.conf

# Attempt 2: with broadcom platform explicit
sensor -U 521:521 -b external -r /data/share/sensor \
  -c /data/home/qnxuser/usb_camera_rpi.conf
# (conf had SENSOR_GLOBAL with libsensor_platform_broadcom.so + BCM2711)

# Attempt 3: ycbycr format - got furthest, camera detected, then USB buffer timeout
# (conf had default_video_format = ycbycr, 640x480, 30fps)

# Attempt 4: nv12 format - frametype not supported error
# Attempt 5: cbycry format - same timeout

# Attempt 6: simulator as unit 1 + USB as unit 2 (dual config)
sensor -U 521:521 -b external -r /data/share/sensor \
  -c /data/home/qnxuser/dual2.conf
# Got: max unit 2, camera2 USB detected, but still Did not find supported data units
```

### Valid sensor config format values

From the QNX docs, these are the valid `default_video_format` strings:
`nv12`, `rgb8888`, `rgb888`, `gray8`, `bayer`, `cbycry`, `rgb565`, `ycbcr420p`, `ycbycr`, `ycrycb`, `crycby`, `bayer14_rggb_padlo16`

The UGREEN 4K camera outputs YUYV (= `ycbycr` in QNX terminology) and MJPEG. Neither works through the broadcom platform on this image.

---

## Next Steps - Getting Camera Working

### Option A - Pi Camera Module v2 or v3 (Recommended)

This is the primary supported camera for this QNX image. Plug into the CSI port, modify `post_startup.sh` and reboot.

```sh
# Edit post_startup.sh to use camera_module3.conf
sed -i 's|sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/sensor_demo.conf|sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/camera_module3.conf|' /usr/etc/startup/post_startup.sh
```

After reboot:
```sh
# Verify it worked
ls /dev/sensor/
# Expected: camera1

# Test with the example
camera_example1_callback -u 1

# Once working, the boopbot app's camera_provider.cpp is already ready
# The CameraWorker class handles both NV12 and RGB8888 formats
./boopbot
```

### Option B - Ask QNX on their developer Discord

The USB camera path is documented and the config files exist. The VCHIQ timeout looks like a bug in this specific image version. The QNX team was responsive when I reported the Wayland issue there. Post the slog2 output showing the timeout.

### Option C - Skip sensor service, use OpenCV

OpenCV 4.12 with videoio is available via apk. If `/dev/video0` can be created via a UVC driver, OpenCV can grab frames directly:

```sh
apk add libopencv_videoio opencv-dev
```

Then in C++ replace the camera_provider with an OpenCV-based one using `cv::VideoCapture(0)`. No sensor service needed. The camera_provider architecture (QQuickImageProvider + background thread + QueuedConnection relay) stays the same, only the frame grabbing changes.

---

## Pi Camera Module - It Worked

I switched to a Raspberry Pi Camera Module connected via the CSI port instead of the UGREEN USB camera. This confirmed the suspicion from Part 5 - the broadcom platform library on this QNX image is built for CSI cameras, not UVC USB cameras.

### Starting the sensor service with the Pi Camera config

```sh
slay sensor
sleep 1
sensor -U 521:521 -b external -r /data/share/sensor/ -c /system/etc/config/sensor/camera_module3.conf
```

Confirmed running with `pidin arg`:
```
884772 sensor -U 521:521 -r /data/share/sensor -c /system/etc/config/sensor/usb_camera.conf
```
(this was the old USB camera instance before I slayed it and started the camera_module3.conf one)

### Verifying with the viewfinder example

```sh
camera_example3_viewfinder
```

This launched without error - no `software termination signal`, no `Did not find supported data units`, no VCHIQ timeout. The Pi Camera Module initializes cleanly through `libsensor_platform_broadcom.so` because that library was built specifically for CSI-connected sensors like this one.

### What this confirms

The root cause analysis from Part 5 was correct: `libsensor_platform_broadcom.so` and its VCHIQ firmware calls work for CSI cameras (Camera Module 3) but hang/fail when trying to enumerate frametypes from a UVC USB camera. Switching to the Pi Camera Module sidesteps the entire problem rather than fixing it.

### Next steps for boopbot integration

With the sensor service running `camera_module3.conf` and the camera confirmed working via `camera_example3_viewfinder`, the existing `camera_provider.cpp` in the boopbot app (Part 5) should now work without modification, since it already handles both `CAMERA_FRAMETYPE_NV12` and `CAMERA_FRAMETYPE_RGB8888`, both of which Camera Module 3 outputs.

To make this permanent across reboots, update `/usr/etc/startup/post_startup.sh` so the camera_module3.conf line is the one that's active instead of sensor_demo.conf:

```sh
sed -i 's|sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/sensor_demo.conf|sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/camera_module3.conf|' /usr/etc/startup/post_startup.sh
```

Then test boopbot:
```sh
cd /data/home/qnxuser/boopbot
export XDG_RUNTIME_DIR=/data/var/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export QT_QPA_PLATFORM=wayland
export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH
./boopbot
```

The camera feed panel should now show the live Pi Camera Module 3 stream instead of `[ NO SIGNAL ]`.

---

| What I saw | Why it happened | Fix |
|---|---|---|
| `Found 0 cameras` from Qt Multimedia | No V4L2 device node, no GStreamer V4L2 plugin | Must use QNX camera API via sensor service |
| `camera_set_vf_mode` returns 22 | CAMERA_ENOTSUP -- USB camera only supports modes 0 and 5 | Use mode 5 or skip set_vf_mode |
| `camera_start_viewfinder` returns 13 | CAMERA_EBUSY -- sensor service holds the camera | Must go through sensor service |
| `camera_start_viewfinder` returns 22 | CAMERA_ENOTSUP -- sensor service not running | Start sensor service first |
| `Did not find supported data units` | Broadcom platform can't enumerate UVC camera frametypes | Use Pi Camera Module, or wait for QNX fix |
| `Timeout waiting for USB buffer` | VCHIQ firmware doesn't respond to UVC format query | Same as above |
| `TIMEOUT waiting for Platform::getPlatform` | Sensor service hung waiting for VCHIQ | Sensor crashes, no `/dev/sensor/camera1` |
| `Failed to open CAMERA_UNIT_2: err = 2` | CAMERA_EAGAIN -- sensor crashed before USB init finished | Same root cause |
| QML abort on camera thread | `CameraWorker` exposed directly to QML engine | Use `CameraRelay` proxy on main thread with `Qt::QueuedConnection` |

---

## Current Status

| Thing | Status |
|---|---|
| QNX SDP 8.0 on Fedora host | Working |
| QNX target RPi4B via SSH | Working |
| TigerVNC to QNX xfce4 desktop | Working |
| Weston compositor on target | Working |
| System Qt 6.10.0 on target via apk | Working |
| Qt Quick boopbot app - UI | Working - black/green terminal aesthetic on VNC |
| Qt Quick boopbot app - camera feed | Not yet retested with Pi Camera Module - expected to work |
| UGREEN 4K USB camera via QNX sensor service | Broken - VCHIQ timeout on broadcom platform |
| Pi Camera Module via QNX sensor service | Working - camera_example3_viewfinder runs clean with camera_module3.conf |
| OpenCV VideoCapture fallback | Not needed - Pi Camera Module path works |

## Part 6: Camera Callback IPC Bug — Root Cause Found, Stream-Mode Fix In Progress

### Root cause (confirmed via isolated standalone probes, bypassing boopbot/Qt entirely)

After extensive guessing against a hand-reconstructed `camera_api.h` (no real QNX SDK headers were ever available on this image — confirmed via `find / -iname camera_api.h`, only our own file exists), we isolated the real bug with clean standalone C++ probes compiled directly against `/usr/lib/libcamapi.so`:

- `camera_open(CAMERA_UNIT_1, ...)` → succeeds (err=0)
- `camera_get_supported_vf_modes()` (real signature: `(handle, numAsked, *numSupported, *modes)`, no maxMin param) → returns modes **{0, 5}** for this imx708/Camera Module 3 setup
- `camera_get_vf_mode()` right after open → camera defaults to mode **5** already
- `camera_set_vf_mode(handle, 5)` → succeeds (err=0)
- `camera_start_viewfinder(handle, nullptr, nullptr, nullptr)` (NO callback) → **succeeds (err=0)**
- `camera_start_viewfinder(handle, realCallbackFnPtr, nullptr, nullptr)` (real callback, otherwise identical) → **fails err=13 (Permission denied)** on `camera_attach_callback`/IPC

**This isolates the bug precisely: any non-null callback passed to `camera_start_viewfinder` causes the Sensor service's callback-attach IPC to fail with permission denied, regardless of vf_mode, regardless of properties set, regardless of running as root.** This is consistent with (though not identical to) QNX's own officially acknowledged bug QNXE-1351: "Running the `camera_example2_events -u 1` example with the Raspberry Pi Camera Module 3 connected to the Raspberry Pi 4 results in a pulse error" (QNX Everywhere release notes, March 9 2026 known issues, no workaround listed). Both bugs point to the same subsystem (event/callback IPC attachment) being broken for this exact hardware combo (RPi4 + Camera Module 3 + external Broadcom platform) in this QNX image build.

### What does NOT work
- Any vf_mode value combined with a real callback function pointer → permission denied (err=13) every time, regardless of mode (tried 0, 2, 5)
- `camera_private_set_vf_property` with guessed `CAMERA_IMGPROP_FORMAT`/`WIDTH`/`HEIGHT` keys → err=22 (invalid param), our header's property key constants are unverified guesses
- `,1001` supplementary group on sensor `-U` flag → no effect on the permission error
- Calling `camera_get_screen_buffer(handle, &buf)` standalone with just the handle → err=22. **This function is NOT a standalone poller** — per QNX docs, it must be called from inside an active callback with the `camera_buffer_t*` the callback receives, converting it to a `screen_buffer_t`. Wrong usage pattern, not a wrong signature.

### What DOES work (verified via isolated probe, not yet wired into boopbot)
```cpp
camera_open(CAMERA_UNIT_1, CAMERA_MODE_RW | CAMERA_MODE_ROLL, &handle);  // err=0
camera_set_vf_mode(handle, (camera_vfmode_t)5);                          // err=0
camera_start_viewfinder(handle, nullptr, nullptr, nullptr);              // err=0, SUCCESS
```
This runs cleanly with the default viewfinder window auto-created (Screen child window managed by Sensor service). Also verified: disabling the window via `camera_private_set_vf_property(handle, CAMERA_IMGPROP_CREATEWINDOW, 0, -1)` before start also succeeds (err=0) with nullptr callback.

### Correct architectural fix (per official QNX docs — "Using stream mode" / "Use streams" pages)
Since callbacks are broken on this hardware, the documented alternative is **Stream mode**:
1. `camera_open()` as normal
2. `camera_set_vf_mode(handle, 5)`
3. `camera_private_set_vf_property(handle, CAMERA_IMGPROP_CREATEWINDOW, 0, -1)` — disable the auto window
4. `camera_start_viewfinder(handle, nullptr, statusCallback_or_nullptr, nullptr)` — no per-frame callback, status callback is optional and separate
5. Use Screen API: `screen_get_event_property_pv()` to catch the producer stream handle from a `SCREEN_EVENT_CREATE`-type event
6. `screen_consume_stream_buffers()` once to bind consumer↔producer streams
7. Loop: `screen_acquire_buffer(&sbuffer, cstream, &count, &dirty, NULL, 0)` to poll/pull frames, `screen_release_buffer()` when done with each

This requires linking against `libscreen.so` and rewriting `camera_provider.cpp`'s `start()`/buffer-handling entirely — replacing the `viewfinderCallback` static function approach with a `QTimer`-driven poll loop calling `screen_acquire_buffer` on a background thread, converting the resulting `screen_buffer_t`'s pixel data (format/stride read via `screen_get_buffer_property_iv`/`_pv`) into a `QImage` the same way `nv12ToRgb`/`rgb8888ToRgb` already do in `camera_provider.cpp`.

### Header reality check
`/data/home/qnxuser/boopbot/camera_api.h` is **entirely hand-reconstructed**, not a real QNX SDK header (this image ships no dev headers — confirmed filesystem-wide search). Known-correct entries so far (verified live against `/usr/lib/libcamapi.so` via `nm -D` + standalone probes): `camera_get_supported_vf_modes` exists with signature `(camera_handle_t, uint32_t numAsked, uint32_t* numSupported, camera_vfmode_t* modes)`, no maxMin param. `camera_vfmode_t` real supported values for this camera are 0 and 5 (NOT the header's guessed `CAMERA_VFMODE_DEFAULT=0, CAMERA_VFMODE_VIDEO=1, CAMERA_VFMODE_PHOTO=2` — value 1 and 2 both fail; only 0 and 5 are accepted by `camera_set_vf_mode`, though 0 still fails to *start* a callback-based viewfinder while 5 is the camera's actual default and works for nullptr-callback start). Property key constants (`CAMERA_IMGPROP_FORMAT`, `WIDTH`, `HEIGHT`) are still unverified guesses — every test so far that touched them returned err=22, so don't trust their numeric values without re-deriving them the same way (isolated probe + `nm -D`/docs cross-reference).

### Next steps
1. Write `camera_provider.cpp` v2 using the stream-mode pattern above (no callbacks, Screen API polling via QTimer).
2. Will need `screen.h`-equivalent declarations added to a new header (same problem as camapi — likely no real header on this image, check `find / -iname screen.h` and `nm -D /usr/lib/libscreen.so` the same way we did for camapi).
3. Add `-lscreen` to CMakeLists.txt link libraries.
4. Backup current `camera_provider.cpp` (callback-based, currently using `camera_set_vf_mode(handle, 5)` + real callback, which we now know will always fail with err=13) before rewriting.

## Part 7: Stream-Mode Rewrite Attempt — New Crash Found, Deeper Than Expected

### What we built
Rewrote `camera_provider.cpp`/`.h` to use Screen stream mode instead of camapi callbacks (full code committed to target, backups at `camera_provider.cpp.bak2`/`camera_provider.h.bak`). Flow: `camera_open` → `camera_set_vf_mode(5)` → `camera_private_set_vf_property(CREATEWINDOW=0)` → `screen_create_context` → `screen_create_window` (kept invisible via `SCREEN_PROPERTY_VISIBLE=0`) → `camera_start_viewfinder(nullptr callback)` → wait for `SCREEN_EVENT_CREATE` via `screen_get_event` loop → `screen_create_stream` (consumer) → `screen_consume_stream_buffers` → poll via `QTimer` calling `screen_acquire_buffer`/`screen_release_buffer`.

### Result: crashes ~12ms after camera actually starts successfully
Confirmed via `slog2info` across two attempts (first with a *visible* window, second with `SCREEN_PROPERTY_VISIBLE=0` set immediately after creation — same crash both times):

```
sensor_service: StateVideoVF::startViewfinder(...): preview 2304x1296, rotation 0, framerate_q16 1e0000 format 15
sensor_service: StateVideoVF::setViewfinderType(...): Starting local window
sensor_service: pid=<boopbot_pid> entered state: VIDEOVF (err:0)
sensor_service: received first preview frame from start of preview   <-- CAMERA ACTUALLY WORKED
camapi.<boopbot_pid>: stream_cleanup(250): Failed to destroy stream: err = 22
camapi.<boopbot_pid>: stream_cleanup(254): Failed to destroy context: err = 22
sensor_service: StateVideoVF::setViewfinderType(...): Stopping local window
sensor_service: StateVideoVF::stopViewfinder(): viewfinder stopped
sensor_service: pid=<boopbot_pid> entered state: CONNECTED -> DISCONNECTED (err:0)
```

Process disappears from `pidin arg` entirely — silent crash/exit, not a hang (confirmed by checking immediately, no Ctrl+C needed).

### Key new finding
The sensor service logs **"Starting local window" / "Stopping local window"** even though we explicitly set `CAMERA_IMGPROP_CREATEWINDOW=0` before calling `camera_start_viewfinder`. This suggests either: (a) our `CAMERA_IMGPROP_CREATEWINDOW` property set isn't actually taking effect / silently ignored on this camapi build, or (b) "local window" here refers to something internal to camapi's own stream management (separate from the app-visible viewfinder window concept), unrelated to our `CREATEWINDOW` property. The crash trace (`stream_cleanup` failing with err=22 on both stream AND context destroy) points to **camapi's own internal Screen context/stream colliding with our separately-created one** — likely both trying to register with the same underlying Screen connection or DRM resource, even with our window kept invisible.

### Ruled out
- Window visibility was NOT the root cause — setting `SCREEN_PROPERTY_VISIBLE=0` immediately after `screen_create_window` did not prevent the crash. Identical failure signature with and without this fix.

### Current state
`camera_provider.cpp`/`.h` on target are in the broken stream-mode state (crashes ~12ms after camera start, every time, 100% reproducible). Backups available: `camera_provider.cpp.bak2`, `camera_provider.h.bak` (pre-stream-mode, callback-based version — also broken, fails with err=13 permission denied on any real callback, but at least doesn't crash). `camera_provider.cpp.bak` (older, even further back).

### Recommended next steps (not yet attempted)
1. **Try CAMERA_IMGPROP_CREATEWINDOW removal entirely** — don't set it at all, let camapi create its default window normally (matches our much-earlier successful isolated probe `probe_vf4.cpp`/`probe_vf6.cpp` results), and instead of creating our OWN separate Screen context/window, try to find and consume FROM the window camapi already creates (need `camera_get_screen_window` or similar — check `nm -D /usr/lib/libcamapi.so | grep -i window` for a getter function we may have missed).
2. Alternatively: investigate whether `camera_start_viewfinder`'s internal "local window" is actually fine and the real conflict is specifically `screen_create_context`/`screen_create_window` being called from the SAME PROCESS as camapi after camapi has already established its own screen connection — try creating our Screen context/window BEFORE calling `camera_open`/`camera_start_viewfinder` at all (reverse the order), in case camapi's internal setup is sensitive to an existing context already being present vs. being created concurrently/after.
3. Check if `camera_3a.h` or other camapi headers (not just `camera_api.h`) have a more direct buffer-access function we're missing — re-run `nm -D /usr/lib/libcamapi.so | grep -iE "window|stream"` exhaustively (not just the get_supported/get_buffer subset checked so far) to catalog every window/stream-related export.
4. As a fallback if stream mode proves unworkable on this image: revisit event mode (camera_get_viewfinder_buffers + camera_enable_event, bound to a real QNX pulse) despite QNXE-1351's pulse-error warning — the known bug is specifically about `camera_example2_events -u 1`, which may not be identical to how OUR event binding would work; worth an isolated probe test before ruling it out.
5. Last resort: have boopbot shell out to / monitor `camera_example3_viewfinder` as a subprocess (the proven, officially-working binary), and find a way to read its output frames indirectly (e.g., have it write to a shared memory segment or named pipe — would require modifying that workflow since the binary itself doesn't support this natively, OR screen-scrape its window via a screenshot-style Screen API call from boopbot if permissions allow capturing another process's window buffer).

## Part 8: Reordering Fix Did NOT Resolve Crash — Corrected Understanding

### Correction to Part 7
Reordering Screen context/window creation to happen BEFORE `camera_open()`/`camera_start_viewfinder()` (per the official QNX doc example's ordering) did NOT fix the crash. Identical failure, same timing (~60-90ms after "Starting local window"), same error (`stream_cleanup` err=22 on both stream and context destroy), same PID pattern. Confirmed via fresh `slog2info` check after this change.

### Updated understanding
The crash is NOT about call ordering between our code and camapi. The sensor_service log line "Starting local window" / "Stopping local window" appears to be **automatic, internal to camapi's own camera_start_viewfinder() implementation**, regardless of whether we set `CAMERA_IMGPROP_CREATEWINDOW=0`. This "local window" is NOT the same as the app-visible viewfinder window the docs describe — it appears to be a transient internal Screen object camapi creates/destroys as part of its own viewfinder startup machinery on this specific platform build, and that internal `stream_cleanup()` call is failing with err=22 every single time, ~60-90ms after the state machine enters VIDEOVF, regardless of whether OUR Screen context was created before or after camera_open.

This means our own `screen_create_context`/`screen_create_window`/`screen_create_event` calls are likely NOT the actual cause of the crash at all (we never confirmed causation, only correlation — both versions crash identically whether our Screen objects exist before or after camera_open). The crash may be **entirely internal to camapi itself on this QNX image/hardware combination**, independent of anything our application does — i.e., a possible second manifestation of the same underlying QNXE-1351-class bug (RPi4 + Camera Module 3 + Sensor Framework instability), this time surfacing during normal `camera_start_viewfinder()` even in `nullptr`-callback/stream mode, not just callback mode.

### Important nuance on "boopbot didn't crash" vs "camera crashed"
In the reordered-version test, `pidin arg` still showed `./boopbot` (pid 7725109) running 5 seconds after launch, BUT the camera's internal state machine had already gone VIDEOVF -> CONNECTED -> DISCONNECTED within the first ~300ms (visible in sensor_service log timestamps). This means: the outer Qt process can survive even when camapi's internal stream_cleanup error occurs, but the camera connection itself is destroyed by the sensor service as a result. Our code's 50x100ms polling loop for `SCREEN_EVENT_CREATE` then runs for ~5 seconds waiting for a stream that will never arrive (since the viewfinder already disconnected), which is very likely why the screen appeared black/frozen — Qt's QML window may not be getting a chance to render/repaint while the CameraWorker thread is busy-polling, OR (more likely, since CameraWorker runs on its own QThread per main.cpp's moveToThread setup) the Wayland/QPA backend itself may be stalling due to the earlier `drmModeAtomicCommit` style conflict from our own (now invisible) Screen window still being registered.

### Recommendation for next session
Given `camera_example3_viewfinder` (the official QNX binary) reportedly worked successfully earlier in this debugging saga (per the master guide's Part 5), and given camapi's own internal stream_cleanup is failing regardless of our code's approach, the most promising remaining paths are:
1. Re-run `camera_example3_viewfinder` fresh right now (sensor service running, no boopbot interference) to confirm whether IT still works cleanly on this image -- if yes, diff its approach (Screen window creation enabled, default CREATEWINDOW=1, not 0) against ours more carefully; the working binary may rely on letting camapi manage its OWN internal Screen window fully (CREATEWINDOW left at default/1) rather than us setting CREATEWINDOW=0 and trying to manage Streams ourselves, which may be the actual unstable code path on this specific camapi build.
2. If default CREATEWINDOW=1 is more stable, pivot back to callback-window mode but instead of pulling frames via a per-frame data callback (which separately also fails with err=13 permission denied, a DIFFERENT bug from this stream_cleanup one), try capturing the auto-created viewfinder window's buffer directly via Screen APIs (screen_get_window_property_pv for SCREEN_PROPERTY_RENDER_BUFFERS) on a QTimer poll, without ever registering our own competing Screen window/context -- i.e. let camapi own 100% of the Screen interaction, and we just peek at its window's buffer externally.
3. Consider contacting QNX support/Discord with the exact two confirmed bugs (err=13 permission denied on callback attach; err=22 stream_cleanup crash in stream mode) referencing QNXE-1351, since both increasingly look like platform-level Sensor Framework bugs specific to RPi4 + Camera Module 3 on this QNX Everywhere image build, not application code issues.

---

# PART 9 — Fresh Image + Sensor Framework 8.0.4 = Camera Working (June 24, 2026)

## Summary

After months of debugging two confirmed QNX platform bugs (err=13 callback IPC permission denied, err=22 stream_cleanup crash), the root cause was finally isolated and fixed by:
1. Flashing the latest QSTI (build 297, June 6 2026) via QNX Software Center
2. Installing `qnx-sensor-framework 8.0.4` via `apk` on the new image
3. Using the new RPi4-specific sensor config `/usr/etc/config/sensor/rpi4_camera_module3.conf`
4. Replacing our hand-reconstructed `camera_api.h` with the real SDK headers (also installed via apk)

Result: `camera_start_viewfinder` with a real callback function now succeeds. CAMERA STATUS shows "Camera streaming". The CAMERA FEED panel shows a live, real-time feed from the Pi Camera Module 3.

---

## Step-by-step of what happened

### 9.1 — Confirming the old image version

Old image was `QNXOS_802_B2005` (Nov 2024, build 2005), confirmed by:
```sh
use -i /system/bin/qconn | grep VERSION
# Returns: VERSION=QNXOS_802_B2005
```

The latest QSTI available was build 297 (June 6 2026). Found in the **Updates (18)** tab of QNX Software Center under Reference Images → QNX® SDP 8.0 Quick Start Target Image for RPi4.

Note: The QSC installed the new image into `~/qnx/SDP/qnx800_2/` not `qnx800_1` — confirm path before flashing.

### 9.2 — Flashing the new image

Flashed with Raspberry Pi Imager:
- Device: Raspberry Pi 4
- OS: Use Custom → `~/qnx/SDP/qnx800_2/images/rpi4/rpi4/rpi4.img`
- Storage: SD card
- OS Customisation: **No** (critical)
- Confirm: Yes

After flashing, build date confirmed via:
```sh
cat /proc/boot/build.date
# Returns: 2026-06-06T15:56:54-04:00
```

Note: `use -i /system/bin/qconn | grep VERSION` still reports `QNXOS_802_B2005` — this is a quirk of that utility (it reflects the SDP version it was compiled against, not the image build). The `build.date` file is the authoritative source.

### 9.3 — Post-flash setup

```sh
# Clear stale SSH host key on Fedora host first
ssh-keygen -R anakafeelqnxpi.local

# On the Pi: generate new SSH key for GitHub
ssh-keygen -t ed25519 -C "boopbot-qnx-pi-build297" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
# Add to github.com/settings/keys → New SSH key (SSH type, not GPG)

ssh -T git@github.com  # verify: "Hi anakafeel!"

# Clone repo
cd /data/home/qnxuser
git clone git@github.com:anakafeel/QT_BOOPBOT.git boopbot
cd boopbot

# Install Qt
apk add qt6-base qt6-base-dev qt6-declarative qt6-declarative-dev qt6-wayland
```

### 9.4 — Installing the sensor framework packages (THE FIX)

This is the critical step. The old QSTI did not include these:

```sh
apk add qnx-sensor-framework \
        qnx-sensor-framework-dev \
        qnx-sensor-framework-camera-imx708 \
        qnx-sensor-framework-camera-imx708-demo \
        qnx-sensor-framework-utils
```

What this installs:
- `qnx-sensor-framework 8.0.4` — fixed sensor framework with working callback IPC
- `qnx-sensor-framework-dev 8.0.4` — **real camera headers** at `/usr/include/camera/`
- `qnx-sensor-framework-camera-imx708 8.0.4` — imx708 driver at `/usr/lib/libimx708_external_camera.so`
- New sensor configs at `/usr/etc/config/sensor/` including `rpi4_camera_module3.conf`
- `sensor_example` binary (new, not in old image)
- `qnx-multimedia-framework 8.0.4` (pulled in as dependency)

### 9.5 — Key differences in the new sensor config

Old config (`/system/etc/config/sensor/camera_module3.conf`):
```
address = /system/lib/libimx708_external_camera.so,1   ← old/broken library
default_video_format = bgr8888
# No algorithm_config
```

New RPi4-specific config (`/usr/etc/config/sensor/rpi4_camera_module3.conf`):
```
address = /usr/lib/libimx708_external_camera.so,1           ← fixed 8.0.4 library
default_video_format = nv12                                  ← matches our NV12 conversion
algorithm_config = /usr/etc/config/sensor/rpi4_algorithm_imx708.json, imx708
```

The old config pointed to `/system/lib/` which had the buggy library. The new config correctly points to `/usr/lib/` which has the fixed 8.0.4 library.

Updated `run.sh` sensor launch:
```sh
# Old (broken):
sensor -U 521:521 -b external -r /data/share/sensor -c /system/etc/config/sensor/camera_module3.conf &

# New (working):
sensor -U 521:521 -b external -r /data/share/sensor -c /usr/etc/config/sensor/rpi4_camera_module3.conf &
```

### 9.6 — Replacing the hand-reconstructed camera_api.h

The old image shipped no camera development headers. The new `qnx-sensor-framework-dev` package installs real headers at:
- `/usr/include/camera/camera_api.h`
- `/usr/include/camera/camera_defs.h`
- `/usr/include/camera/camera_config.h`
- `/usr/include/camera/camera_extended.h`
- `/usr/include/camera/camera_image_attr.h`

Replaced our hand-reconstructed `camera_api.h` with a redirect:
```cpp
// camera_api.h — now just a redirect to real headers
#pragma once
#include <camera/camera_api.h>
#include <camera/camera_defs.h>
#include <camera/camera_config.h>
```

The real `camera_buffer_t` struct field names (`frametype`, `framebuf`, `framedesc`) turned out to match our original guesses. The bug was entirely in the sensor framework library, not our struct field access.

Also updated `camera_provider.h` to use `CAMERA_HANDLE_INVALID` instead of `-1` for handle initialisation.

### 9.7 — Final working camera_provider.cpp flow

```cpp
void CameraWorker::start() {
    emit statusChanged("Opening camera...");
    camera_open(CAMERA_UNIT_1, CAMERA_MODE_RW | CAMERA_MODE_ROLL, &m_handle); // err=0
    camera_set_vf_mode(m_handle, (camera_vfmode_t)5);                         // err=0, mode 5 = default
    m_running = true;
    camera_start_viewfinder(m_handle, viewfinderCallback, nullptr, this);     // err=0 ✓ WORKS
    emit statusChanged("Camera streaming");
}
```

Callback fires with `camera_buffer_t*` containing NV12 frames at 2304x1296. NV12→QImage conversion in `processFrame` works correctly. `frameReady()` signal triggers QML image refresh via `image://camera/frame?N` URL pattern.

### 9.8 — MESA GPU memory exhaustion (cosmetic, fix: reboot)

After multiple crash cycles during the testing session, GPU memory got exhausted:
```
MESA: error: Failed to allocate device memory for BO
Screen display dpy-1 not found!
Abort (core dumped)
```
Fix: full reboot of the Pi (`reboot` or physically power-cycle). After reboot, camera streams live with no issues.

### 9.9 — Complete working setup checklist (fresh QSTI build 297)

```sh
# 1. Install Qt
apk add qt6-base qt6-base-dev qt6-declarative qt6-declarative-dev qt6-wayland

# 2. Install sensor framework (THE CRITICAL STEP)
apk add qnx-sensor-framework qnx-sensor-framework-dev \
        qnx-sensor-framework-camera-imx708 \
        qnx-sensor-framework-camera-imx708-demo \
        qnx-sensor-framework-utils

# 3. Clone and build
git clone git@github.com:anakafeel/QT_BOOPBOT.git boopbot
cd boopbot
./build.sh

# 4. Run
./run.sh
```

### 9.10 — Root cause summary table

| Bug | Error code | Root cause | Fix |
|-----|-----------|------------|-----|
| `camera_start_viewfinder` fails with callback | err=13 Permission denied | Broken callback IPC in sensor framework ≤8.0.2 | Install `qnx-sensor-framework 8.0.4` via apk |
| Stream mode crash | err=22 stream_cleanup | Internal camapi stream/context teardown bug in old libs | Same — fixed in 8.0.4 |
| Wrong library loaded by sensor service | Silent failure / wrong behaviour | Old config pointed to `/system/lib/` (buggy), not `/usr/lib/` (fixed 8.0.4) | Use `rpi4_camera_module3.conf` |
| Wrong enum values / type mismatches | Various err=22 | Hand-reconstructed `camera_api.h` with guessed values | Use real headers from `qnx-sensor-framework-dev` |
| GPU memory exhaustion after testing | MESA BO alloc errors, abort | Multiple crash cycles leak GPU memory | Reboot the Pi |


---

# PART 10 — Team Onboarding (Windows + Shared Pi Setup)

## Overview

Since BOOPBOT builds natively on the Pi itself (not cross-compiled from the host), teammates on **any OS** (Windows, Mac, Linux) only need three things:
1. An SSH client to get into the Pi
2. TigerVNC to see the UI
3. Git (optional — can also just use git on the Pi directly)

No QNX SDP installation, no Qt download, no cross-compilation toolchain needed on their machine.

---

## 10.1 — Windows setup for teammates

### Tools to install on Windows
- **SSH**: already built into Windows 10/11 — open PowerShell or Windows Terminal and type `ssh`
- **TigerVNC viewer**: download from https://tigervnc.org → Windows installer → connect to `anakafeelqnxpi.local:5900`
- **VS Code** (optional but recommended): install the **Remote - SSH** extension, then connect to `qnxuser@anakafeelqnxpi.local` — gives full file editing, terminal, and source control on the Pi remotely

### Connecting to the Pi
```sh
# In PowerShell or Windows Terminal:
ssh qnxuser@anakafeelqnxpi.local
# Enter password when prompted
```

---

## 10.2 — First-time Pi setup for a new teammate

Once SSHed into the Pi, run these once (only needed the first time):

```sh
# 1. Install Qt (if not already installed)
apk add qt6-base qt6-base-dev qt6-declarative qt6-declarative-dev qt6-wayland

# 2. Install sensor framework (CRITICAL — camera won't work without this)
apk add qnx-sensor-framework \
        qnx-sensor-framework-dev \
        qnx-sensor-framework-camera-imx708 \
        qnx-sensor-framework-camera-imx708-demo \
        qnx-sensor-framework-utils

# 3. Clone the repo as qnxuser (important: clone as qnxuser, NOT as root)
#    Clone into your own directory to avoid permission issues
cd /data/home/qnxuser
git clone https://github.com/anakafeel/QT_BOOPBOT.git boopbot
cd boopbot

# 4. Build and run
./build.sh
./run.sh
```

**Important**: Always clone as `qnxuser`, not as `root`. If the repo was cloned as root, delete it and re-clone as qnxuser — otherwise git operations will fail with permission denied errors.

---

## 10.3 — Git and GitHub setup for teammates

### Option A: HTTPS (recommended for teammates — simplest)

No SSH key generation needed. Just need a GitHub Personal Access Token (PAT):

1. Go to github.com → Settings → Developer settings → Personal access tokens → Tokens (classic) → Generate new token
2. Give it a name, set expiry, check the `repo` scope → Generate → **Copy immediately** (shown once only)

Then on the Pi:
```sh
# Configure identity
git config --global user.name "Your Name"
git config --global user.email "your-github-email@example.com"

# Save credentials so you don't have to re-enter every time
git config --global credential.helper store

# Clone via HTTPS
git clone https://github.com/anakafeel/QT_BOOPBOT.git boopbot

# First push/pull will ask for credentials:
# Username: your-github-username
# Password: paste your PAT token here (not your actual GitHub password)
```

### Option B: SSH keys (alternative)

```sh
# Generate key on the Pi
ssh-keygen -t ed25519 -C "your-label" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
# Copy the output

# Add to GitHub: github.com/settings/keys → New SSH key → paste → Save

# Test connection
ssh -T git@github.com
# Should say: Hi <username>! You've successfully authenticated...

# Clone via SSH
git clone git@github.com:anakafeel/QT_BOOPBOT.git boopbot
```

### Tell git to trust the repo directory (if you get "dubious ownership" error)

This happens when the repo was previously cloned as a different user (root):
```sh
git config --global --add safe.directory /data/home/qnxuser/boopbot
```
Better fix: delete and re-clone as qnxuser so ownership is correct from the start.

### Create your own branch

```sh
cd boopbot
git checkout -b your-name
# Make your changes, then:
git add .
git commit -m "feat: your changes"
git push origin your-name
```

### Add teammates as collaborators on GitHub

The repo owner (anakafeel) needs to add teammates:
- github.com/anakafeel/QT_BOOPBOT → Settings → Collaborators → Add people → enter their GitHub username

---

## 10.4 — VS Code Remote SSH workflow (recommended)

This gives the best development experience on Windows — edit files directly on the Pi with full syntax highlighting, git integration, and a terminal, all from Windows.

1. Install VS Code on Windows
2. Install the **Remote - SSH** extension (search "Remote SSH" in Extensions)
3. Press `Ctrl+Shift+P` → "Remote-SSH: Connect to Host" → enter `qnxuser@anakafeelqnxpi.local`
4. Once connected, click **File → Open Folder** → navigate to `/data/home/qnxuser/boopbot` → OK
5. VS Code now shows the full repo with git source control, file explorer, and terminal

**Important**: Open the exact repo folder (`/data/home/qnxuser/boopbot`), not a parent directory — otherwise VS Code won't detect the `.git` repo and Source Control won't work.

---

## 10.5 — Understanding the codebase (for new contributors)

Only two files need to be touched for most UI work:

### `Main.qml` — the entire UI

**Adding a button**: find the `Repeater` model list and add one line:
```qml
{ label: "YOUR BUTTON", endpoint: "/api/whatever" },
```
That's it — the button appears automatically in the sidebar.

**Changing colors**: every `color: "#xxxxxx"` is a hex code, just swap it.

**CUHacking color palette used**:
- `#12091e` — background
- `#7c3aed` / `#8b5cf6` — primary purple accents
- `#a78bfa` — light lavender text
- `#4c1d95` — dim/secondary text
- `#3b1f6e` — borders
- `#1a0f2e` — panel/header backgrounds

### `camera_provider.cpp` — camera backend

Only touch this if working on frame processing or camera behaviour. The key function is `processFrame(camera_buffer_t* buffer)` which converts raw NV12 frames from the Pi Camera Module 3 into `QImage` objects that QML can display.

### Files to leave alone
- `main.cpp` — app entry point and signal/slot wiring, no reason to edit
- `camera_api.h` — redirect to real QNX camera headers, don't modify
- `CMakeLists.txt` — only touch if adding new `.cpp` source files

---

## 10.6 — Common issues for new teammates

| Issue | Cause | Fix |
|-------|-------|-----|
| `camera/camera_api.h: No such file` on build | `qnx-sensor-framework-dev` not installed | `apk add qnx-sensor-framework-dev` |
| `Permission denied` on git operations | Repo was cloned as root | Delete and re-clone as qnxuser |
| `Dubious ownership` git error | Files owned by different user | `git config --global --add safe.directory /path/to/repo` |
| VS Code Source Control not showing repo | Wrong folder opened | File → Open Folder → select the actual repo folder |
| Camera shows NO SIGNAL | Sensor service not running | `./run.sh` handles this automatically |
| MESA GPU memory errors / black screen | GPU memory leaked from crashed runs | Reboot the Pi |
| `ssh: Could not resolve hostname` | Running Pi command locally instead of in SSH session | SSH into Pi first, then run commands |

