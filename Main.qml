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

    property int frameCounter: 0

    Connections {
        target: cameraRelay
        function onFrameReady() {
            root.frameCounter++
            cameraImage.source = ""
            cameraImage.source = "image://camera/frame?" + root.frameCounter
        }
        function onStatusChanged(status) {
            statusLabel.text = status
        }
    }

    // Header bar
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        color: "#1a0f2e"
        border.color: "#7c3aed"
        border.width: 1

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // CUHacking logo
            Image {
                width: 32
                height: 32
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
                width: 8; height: 8
                radius: 4
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
                interval: 1000
                running: true
                repeat: true
                onTriggered: parent.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
            }
        }
    }

    // Main content area
    Row {
        anchors.top: header.bottom
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: statusBar.top
        spacing: 1

        // Camera feed panel
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
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 32
                height: parent.height - 48
                color: "#0a0618"
                border.color: "#7c3aed"
                border.width: 1

                Image {
                    id: cameraImage
                    anchors.fill: parent
                    anchors.margins: 2
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    source: "image://camera/frame?0"

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        visible: cameraImage.status !== Image.Ready || root.frameCounter === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            // CUHacking logo (pulsing, centered)
                            Image {
                                width: 64
                                height: 64
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

                Canvas {
                    anchors.fill: parent
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
            }
        }

        // Right panel
        Rectangle {
            width: parent.width * 0.35 - 2
            height: parent.height
            color: "#12091e"
            border.color: "#3b1f6e"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Text {
                    text: "SYSTEM CONTROL"
                    color: "#a78bfa"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.letterSpacing: 3
                    opacity: 0.7
                }

                Rectangle { width: parent.width; height: 1; color: "#3b1f6e" }

                Repeater {
                    model: [
                        { label: "CAPTURE FRAME",  endpoint: "/api/capture"  },
                        { label: "DETECT OBJECTS", endpoint: "/api/detect"   },
                        { label: "START RECORD",   endpoint: "/api/record"   },
                        { label: "SYSTEM STATUS",  endpoint: "/api/status"   },
                        { label: "RESET CAMERA",   endpoint: "/api/reset"    },
                    ]

                    delegate: Rectangle {
                        width: parent.width
                        height: 32
                        color: mouseArea.pressed ? "#3b1f6e" : (mouseArea.containsMouse ? "#2d1657" : "#1a0f2e")
                        border.color: mouseArea.containsMouse ? "#a78bfa" : "#3b1f6e"
                        border.width: 1
                        radius: 2

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Text {
                                text: ">"
                                color: "#8b5cf6"
                                font.family: "monospace"
                                font.pixelSize: 14
                                font.bold: true
                                opacity: mouseArea.containsMouse ? 1.0 : 0.5
                            }

                            Text {
                                text: modelData.label
                                color: "#a78bfa"
                                font.family: "monospace"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                apiResponseLabel.text = "[ " + modelData.endpoint + " ] called"
                                apiFlash.restart()
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#3b1f6e" }

                Text {
                    text: "API RESPONSE"
                    color: "#a78bfa"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.letterSpacing: 3
                    opacity: 0.7
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    color: "#0a0618"
                    border.color: "#3b1f6e"
                    border.width: 1
                    radius: 2

                    Text {
                        id: apiResponseLabel
                        anchors.fill: parent
                        anchors.margins: 10
                        text: "Awaiting command..."
                        color: "#8b5cf6"
                        font.family: "monospace"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap

                        SequentialAnimation {
                            id: apiFlash
                            PropertyAnimation { target: apiResponseLabel; property: "color"; to: "#a78bfa"; duration: 100 }
                            PropertyAnimation { target: apiResponseLabel; property: "color"; to: "#8b5cf6"; duration: 400 }
                        }
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
            }
        }
    }

    // Status bar
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
            Text { text: "RPi4B aarch64le";   color: "#4c1d95"; font.family: "monospace"; font.pixelSize: 11 }
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
