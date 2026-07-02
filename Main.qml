import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: root
    width: 700
    height: 480
    visible: true
    title: "BOOPBOT"
    color: "#12091e"

    property int frameCounter:   0
    property int countdownValue: 3
    property string capturedPhoto: ""
    property var photoList: []
    property string appState: "live"
    property string selectedWallPhoto: ""

    Connections {
        target: cameraRelay
        function onFrameReady() {
            root.frameCounter++
            cameraImage.source = ""
            cameraImage.source = "image://camera/frame?" + root.frameCounter
        }
        function onStatusChanged(status) { statusLabel.text = status }
        function onPhotoCaptured(path) {
            root.capturedPhoto = "file://" + path
            root.appState = "reveal"
            revealTimer.restart()
        }
        function onPhotoListChanged(photos) {
            root.photoList = photos
            if (photos.length > 0) root.selectedWallPhoto = photos[0]
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.countdownValue > 1) {
                root.countdownValue--
            } else {
                stop()
                cameraRelay.capturePhoto()
                root.countdownValue = 3
            }
        }
    }

    Timer {
        id: revealTimer
        interval: 10000
        repeat: false
        onTriggered: root.appState = "live"
    }

    // ── HEADER ────────────────────────────────────────────────────────────
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "#1a0f2e"
        border.color: "#7c3aed"
        border.width: 1
        z: 10

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Image {
                width: 32; height: 32
                source: "file:///data/home/qnxuser/boopbot/icon_purple.png"
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "BOOPBOT v1.0"
                color: "#a78bfa"
                font.family: "monospace"
                font.pixelSize: 18
                font.bold: true
                font.letterSpacing: 3
            }
            Rectangle {
                width: 8; height: 8; radius: 4
                color: "#8b5cf6"
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 800 }
                    NumberAnimation { to: 1.0; duration: 800 }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(new Date(), "hh:mm:ss")
            color: "#a78bfa"
            font.family: "monospace"
            font.pixelSize: 13
            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: parent.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
            }
        }
    }

    // ── MAIN ROW ──────────────────────────────────────────────────────────
    Row {
        anchors.top: header.bottom
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: statusBar.top
        spacing: 1

        // ── LEFT: CAMERA FEED ─────────────────────────────────────────────
        Rectangle {
            width: parent.width * 0.65
            height: parent.height
            color: "#12091e"
            border.color: "#3b1f6e"
            border.width: 1

            Text {
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                text: "CAMERA FEED"
                color: "#a78bfa"
                font.family: "monospace"
                font.pixelSize: 11
                font.letterSpacing: 4
                opacity: 0.7
                visible: root.appState === "live" || root.appState === "countdown"
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 32
                height: parent.height - 48
                color: "#0a0618"
                border.color: "#7c3aed"
                border.width: 1
                clip: true

                // ── LIVE FEED ──────────────────────────────────────────────
                Image {
                    id: cameraImage
                    anchors.fill: parent
                    anchors.margins: 2
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    source: "image://camera/frame?0"
                    visible: root.appState === "live" || root.appState === "countdown"

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        visible: cameraImage.status !== Image.Ready || root.frameCounter === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Image {
                                width: 64; height: 64
                                source: "file:///data/home/qnxuser/boopbot/icon_purple.png"
                                fillMode: Image.PreserveAspectFit
                                anchors.horizontalCenter: parent.horizontalCenter
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.4; duration: 600 }
                                    NumberAnimation { to: 1.0; duration: 600 }
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "[ NO SIGNAL ]"
                                color: "#8b5cf6"
                                font.family: "monospace"
                                font.pixelSize: 20
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Initializing camera..."
                                color: "#4c1d95"
                                font.family: "monospace"
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                // Corner brackets (live/countdown only)
                Canvas {
                    anchors.fill: parent
                    visible: root.appState === "live" || root.appState === "countdown"
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.strokeStyle = "#7c3aed"
                        ctx.lineWidth = 2
                        var s = 16
                        ctx.beginPath(); ctx.moveTo(0,s); ctx.lineTo(0,0); ctx.lineTo(s,0); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(width-s,0); ctx.lineTo(width,0); ctx.lineTo(width,s); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(0,height-s); ctx.lineTo(0,height); ctx.lineTo(s,height); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(width-s,height); ctx.lineTo(width,height); ctx.lineTo(width,height-s); ctx.stroke()
                    }
                }

                // ── COUNTDOWN OVERLAY ──────────────────────────────────────
                Rectangle {
                    anchors.fill: parent
                    color: "#aa12091e"
                    visible: root.appState === "countdown"

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.countdownValue
                            color: "#ffffff"
                            font.family: "monospace"
                            font.pixelSize: 120
                            font.bold: true
                            style: Text.Outline
                            styleColor: "#7c3aed"
                            SequentialAnimation on scale {
                                running: root.appState === "countdown"
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.2; duration: 200; easing.type: Easing.OutQuad }
                                NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InQuad }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "GET READY!"
                            color: "#a78bfa"
                            font.family: "monospace"
                            font.pixelSize: 18
                            font.letterSpacing: 4
                        }
                    }
                }

                // ── PHOTO REVEAL ───────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.appState === "reveal"

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        source: root.capturedPhoto
                        cache: false
                    }

                    // Border overlay — replace Rectangle with Image when real PNG arrives:
                    // Image { anchors.fill: parent; source: "file:///data/border.png" }
                    Item {
                        anchors.fill: parent

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 40
                            color: "#e612091e"

                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Image {
                                    width: 24; height: 24
                                    source: "file:///data/home/qnxuser/boopbot/icon_purple.png"
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "CUHacking 2026"
                                    color: "#a78bfa"
                                    font.family: "monospace"
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.letterSpacing: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 36
                            color: "#e612091e"

                            Text {
                                anchors.centerIn: parent
                                text: "July 10–12, 2026  •  Carleton University"
                                color: "#8b5cf6"
                                font.family: "monospace"
                                font.pixelSize: 11
                            }
                        }

                        Rectangle { width: 4; height: 40; color: "#7c3aed"; anchors.top: parent.top; anchors.left: parent.left }
                        Rectangle { width: 4; height: 40; color: "#7c3aed"; anchors.top: parent.top; anchors.right: parent.right }
                        Rectangle { width: 4; height: 40; color: "#7c3aed"; anchors.bottom: parent.bottom; anchors.left: parent.left }
                        Rectangle { width: 4; height: 40; color: "#7c3aed"; anchors.bottom: parent.bottom; anchors.right: parent.right }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 44
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "📸  PHOTO TAKEN!"
                            color: "#ffffff"
                            font.family: "monospace"
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Tap anywhere to dismiss"
                            color: "#8b5cf6"
                            font.family: "monospace"
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            revealTimer.stop()
                            root.appState = "live"
                        }
                    }
                }

                // ── WALL FEATURED PHOTO (left panel) ─────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.appState === "wall"

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectFit
                        source: root.selectedWallPhoto
                        cache: false
                    }

                    // Mini border overlay
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 32
                        color: "#dd12091e"
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Image {
                                width: 18; height: 18
                                source: "file:///data/home/qnxuser/boopbot/icon_purple.png"
                                fillMode: Image.PreserveAspectFit
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "CUHacking 2026"
                                color: "#a78bfa"
                                font.family: "monospace"
                                font.pixelSize: 12
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 28
                        color: "#dd12091e"
                        Text {
                            anchors.centerIn: parent
                            text: "July 10–12, 2026  •  Carleton University"
                            color: "#8b5cf6"
                            font.family: "monospace"
                            font.pixelSize: 10
                        }
                    }

                    Rectangle { width: 3; height: 32; color: "#7c3aed"; anchors.top: parent.top; anchors.left: parent.left }
                    Rectangle { width: 3; height: 32; color: "#7c3aed"; anchors.top: parent.top; anchors.right: parent.right }
                    Rectangle { width: 3; height: 28; color: "#7c3aed"; anchors.bottom: parent.bottom; anchors.left: parent.left }
                    Rectangle { width: 3; height: 28; color: "#7c3aed"; anchors.bottom: parent.bottom; anchors.right: parent.right }

                    Text {
                        anchors.centerIn: parent
                        text: "Select a photo →"
                        color: "#4c1d95"
                        font.family: "monospace"
                        font.pixelSize: 13
                        visible: root.selectedWallPhoto === ""
                    }
                }
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 24
                text: "FRAMES: " + root.frameCounter
                color: "#4c1d95"
                font.family: "monospace"
                font.pixelSize: 11
                visible: root.appState === "live"
            }
        }

        // ── RIGHT PANEL ───────────────────────────────────────────────────
        Rectangle {
            width: parent.width * 0.35 - 2
            height: parent.height
            color: "#12091e"
            border.color: "#3b1f6e"
            border.width: 1

            // ── LIVE/COUNTDOWN CONTROLS ───────────────────────────────────
            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                visible: root.appState === "live" || root.appState === "countdown"

                Text {
                    text: "SYSTEM CONTROL"
                    color: "#a78bfa"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.letterSpacing: 3
                    opacity: 0.7
                }

                Rectangle { width: parent.width; height: 1; color: "#3b1f6e" }

                // CAPTURE button
                Rectangle {
                    width: parent.width
                    height: 48
                    color: captureArea.pressed ? "#5b21b6" :
                           (captureArea.containsMouse ? "#3b1f6e" : "#2d1657")
                    border.color: captureArea.containsMouse ? "#a78bfa" : "#7c3aed"
                    border.width: 2
                    radius: 4

                    Row {
                        anchors.centerIn: parent
                        spacing: 10
                        Text {
                            text: "📸"
                            font.pixelSize: 20
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.appState === "countdown" ? "GET READY..." : "CAPTURE FRAME"
                            color: "#ffffff"
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: captureArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.appState === "live"
                        onClicked: {
                            root.appState = "countdown"
                            root.countdownValue = 3
                            countdownTimer.restart()
                        }
                    }
                }

                // PHOTO WALL button
                Rectangle {
                    width: parent.width
                    height: 36
                    color: wallArea.pressed ? "#3b1f6e" :
                           (wallArea.containsMouse ? "#2d1657" : "#1a0f2e")
                    border.color: wallArea.containsMouse ? "#a78bfa" : "#3b1f6e"
                    border.width: 1
                    radius: 2

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Text { text: ">"; color: "#8b5cf6"; font.family: "monospace"; font.pixelSize: 14; font.bold: true }
                        Text {
                            text: "PHOTO WALL  (" + root.photoList.length + ")"
                            color: "#a78bfa"; font.family: "monospace"; font.pixelSize: 13; font.bold: true
                        }
                    }
                    MouseArea {
                        id: wallArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.appState = "wall"
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#3b1f6e" }

                Text {
                    text: "CAMERA STATUS"
                    color: "#a78bfa"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.letterSpacing: 3
                    opacity: 0.7
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#0a0618"
                    border.color: "#3b1f6e"
                    border.width: 1
                    radius: 2
                    Text {
                        id: statusLabel
                        anchors.fill: parent
                        anchors.margins: 10
                        text: "Initializing..."
                        color: "#8b5cf6"
                        font.family: "monospace"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#3b1f6e" }

                Text {
                    text: "LAST PHOTO"
                    color: "#a78bfa"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.letterSpacing: 3
                    opacity: 0.7
                }

                // Last photo with border overlay
                Rectangle {
                    width: parent.width
                    height: width * 0.6
                    color: "#0a0618"
                    border.color: "#3b1f6e"
                    border.width: 1
                    radius: 2
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectCrop
                        source: root.photoList.length > 0 ? root.photoList[0] : ""
                        cache: false
                        visible: root.photoList.length > 0
                    }

                    // Mini border overlay on thumbnail
                    Item {
                        anchors.fill: parent
                        visible: root.photoList.length > 0

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 16
                            color: "#cc12091e"
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                Image {
                                    width: 10; height: 10
                                    source: "file:///data/home/qnxuser/boopbot/icon_purple.png"
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "CUHacking 2026"
                                    color: "#a78bfa"
                                    font.family: "monospace"
                                    font.pixelSize: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 12
                            color: "#cc12091e"
                            Text {
                                anchors.centerIn: parent
                                text: "July 10–12 • Carleton"
                                color: "#8b5cf6"
                                font.family: "monospace"
                                font.pixelSize: 7
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No photos yet"
                        color: "#4c1d95"
                        font.family: "monospace"
                        font.pixelSize: 11
                        visible: root.photoList.length === 0
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.photoList.length > 0
                        onClicked: {
                            root.capturedPhoto = root.photoList[0]
                            root.appState = "reveal"
                            revealTimer.stop()
                        }
                    }
                }
            }

            // ── WALL VIEW ─────────────────────────────────────────────────
            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                visible: root.appState === "wall"

                Row {
                    width: parent.width
                    spacing: 4

                    Text {
                        text: "PHOTO WALL"
                        color: "#a78bfa"
                        font.family: "monospace"
                        font.pixelSize: 11
                        font.letterSpacing: 3
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: parent.width - backBtn.width - 100; height: 1 }

                    Rectangle {
                        id: backBtn
                        width: 60; height: 22
                        color: backArea.containsMouse ? "#3b1f6e" : "#1a0f2e"
                        border.color: "#7c3aed"; border.width: 1; radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "< BACK"
                            color: "#a78bfa"; font.family: "monospace"; font.pixelSize: 10
                        }
                        MouseArea {
                            id: backArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.appState = "live"
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#3b1f6e" }

                // Grid of thumbnails
                GridView {
                    id: photoGrid
                    width: parent.width
                    height: parent.height - 60
                    cellWidth: width / 3
                    cellHeight: cellWidth * 0.75
                    clip: true
                    model: root.photoList

                    delegate: Rectangle {
                        width: photoGrid.cellWidth - 3
                        height: photoGrid.cellHeight - 3
                        color: root.selectedWallPhoto === modelData ? "#3b1f6e" : "#0a0618"
                        border.color: root.selectedWallPhoto === modelData ? "#a78bfa" : "#3b1f6e"
                        border.width: 1
                        radius: 2
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            fillMode: Image.PreserveAspectCrop
                            source: modelData
                            cache: false
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.selectedWallPhoto = modelData
                            onDoubleClicked: {
                                root.capturedPhoto = modelData
                                root.appState = "reveal"
                                revealTimer.stop()
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.photoList.length === 0 ? "No photos yet — hit CAPTURE!" : "Tap photo to preview • Double-tap to fullscreen"
                    color: "#4c1d95"
                    font.family: "monospace"
                    font.pixelSize: 9
                }
            }

            // ── REVEAL SIDEBAR ────────────────────────────────────────────
            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                visible: root.appState === "reveal"

                Text {
                    text: "PHOTO CAPTURED"
                    color: "#a78bfa"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.letterSpacing: 3
                    opacity: 0.7
                }

                Rectangle { width: parent.width; height: 1; color: "#3b1f6e" }

                Text {
                    width: parent.width
                    text: "📸 Saved to /data/photos/"
                    color: "#8b5cf6"
                    font.family: "monospace"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    text: "Tap photo to dismiss\nor wait 10s"
                    color: "#4c1d95"
                    font.family: "monospace"
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }

                Rectangle { width: parent.width; height: 1; color: "#3b1f6e" }

                Text {
                    text: "TOTAL PHOTOS"
                    color: "#a78bfa"
                    font.family: "monospace"
                    font.pixelSize: 11
                    opacity: 0.7
                }

                Text {
                    text: root.photoList.length
                    color: "#ffffff"
                    font.family: "monospace"
                    font.pixelSize: 40
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: parent.width
                    height: 36
                    color: viewWallArea.containsMouse ? "#3b1f6e" : "#1a0f2e"
                    border.color: "#7c3aed"; border.width: 1; radius: 2

                    Text {
                        anchors.centerIn: parent
                        text: "> VIEW PHOTO WALL"
                        color: "#a78bfa"
                        font.family: "monospace"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    MouseArea {
                        id: viewWallArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            revealTimer.stop()
                            root.appState = "wall"
                        }
                    }
                }
            }
        }
    }

    // ── STATUS BAR ────────────────────────────────────────────────────────
    Rectangle {
        id: statusBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        color: "#1a0f2e"
        border.color: "#7c3aed"
        border.width: 1

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24
            Text { text: "QNX SDP 8.0";      color: "#4c1d95"; font.family: "monospace"; font.pixelSize: 11 }
            Text { text: "RPi5 aarch64le";    color: "#4c1d95"; font.family: "monospace"; font.pixelSize: 11 }
            Text { text: "Qt 6.10 | Wayland"; color: "#4c1d95"; font.family: "monospace"; font.pixelSize: 11 }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "CUHacking 2026"
            color: "#4c1d95"
            font.family: "monospace"
            font.pixelSize: 11
        }
    }
}
