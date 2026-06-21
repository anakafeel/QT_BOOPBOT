import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: root
    width: 700
    height: 480
    visible: true
    title: "BOOPBOT"
    color: "#0a0a0a"

    // Refresh camera feed
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
        color: "#0d0d0d"
        border.color: "#00ff41"
        border.width: 1

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 10; height: 10
                radius: 5
                color: "#00ff41"
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 800 }
                    NumberAnimation { to: 1.0; duration: 800 }
                }
            }

            Text {
                text: "BOOPBOT v1.0"
                color: "#00ff41"
                font.family: "monospace"
                font.pixelSize: 18
                font.bold: true
                font.letterSpacing: 3
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(new Date(), "hh:mm:ss")
            color: "#00ff41"
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
            color: "#0a0a0a"
            border.color: "#1a3a1a"
            border.width: 1

            Text {
                anchors.top: parent.top
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                text: "CAMERA FEED"
                color: "#00ff41"
                font.family: "monospace"
                font.pixelSize: 11
                font.letterSpacing: 4
                opacity: 0.7
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 32
                height: parent.height - 48
                color: "#050505"
                border.color: "#00ff41"
                border.width: 1

                Image {
                    id: cameraImage
                    anchors.fill: parent
                    anchors.margins: 2
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    source: "image://camera/frame?0"

                    // No signal overlay
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        visible: cameraImage.status !== Image.Ready || root.frameCounter === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "[ NO SIGNAL ]"
                                color: "#00ff41"
                                font.family: "monospace"
                                font.pixelSize: 20
                                font.bold: true
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.3; duration: 600 }
                                    NumberAnimation { to: 1.0; duration: 600 }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Initializing camera..."
                                color: "#005c1a"
                                font.family: "monospace"
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                // Corner brackets
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.strokeStyle = "#00ff41"
                        ctx.lineWidth = 2
                        var s = 16
                        // TL
                        ctx.beginPath(); ctx.moveTo(0,s); ctx.lineTo(0,0); ctx.lineTo(s,0); ctx.stroke()
                        // TR
                        ctx.beginPath(); ctx.moveTo(width-s,0); ctx.lineTo(width,0); ctx.lineTo(width,s); ctx.stroke()
                        // BL
                        ctx.beginPath(); ctx.moveTo(0,height-s); ctx.lineTo(0,height); ctx.lineTo(s,height); ctx.stroke()
                        // BR
                        ctx.beginPath(); ctx.moveTo(width-s,height); ctx.lineTo(width,height); ctx.lineTo(width,height-s); ctx.stroke()
                    }
                }
            }

            // FPS counter
            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 24
                text: "FRAMES: " + root.frameCounter
                color: "#004d14"
                font.family: "monospace"
                font.pixelSize: 11
            }
        }

        // Right panel
        Rectangle {
            width: parent.width * 0.35 - 2
            height: parent.height
            color: "#0a0a0a"
            border.color: "#1a3a1a"
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                // Section label
                Text {
                    text: "SYSTEM CONTROL"
                    color: "#00ff41"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.letterSpacing: 3
                    opacity: 0.7
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#1a3a1a"
                }

                // API Buttons
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
                        color: mouseArea.pressed ? "#003d0f" : (mouseArea.containsMouse ? "#001f07" : "#0d1a0d")
                        border.color: mouseArea.containsMouse ? "#00ff41" : "#1a3a1a"
                        border.width: 1
                        radius: 2

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Text {
                                text: ">"
                                color: "#00ff41"
                                font.family: "monospace"
                                font.pixelSize: 14
                                font.bold: true
                                opacity: mouseArea.containsMouse ? 1.0 : 0.5
                            }

                            Text {
                                text: modelData.label
                                color: "#00ff41"
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

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#1a3a1a"
                }

                Text {
                    text: "API RESPONSE"
                    color: "#00ff41"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.letterSpacing: 3
                    opacity: 0.7
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    color: "#050505"
                    border.color: "#1a3a1a"
                    border.width: 1
                    radius: 2

                    Text {
                        id: apiResponseLabel
                        anchors.fill: parent
                        anchors.margins: 10
                        text: "Awaiting command..."
                        color: "#00b32d"
                        font.family: "monospace"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap

                        SequentialAnimation {
                            id: apiFlash
                            PropertyAnimation { target: apiResponseLabel; property: "color"; to: "#00ff41"; duration: 100 }
                            PropertyAnimation { target: apiResponseLabel; property: "color"; to: "#00b32d"; duration: 400 }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#1a3a1a"
                }

                Text {
                    text: "CAMERA STATUS"
                    color: "#00ff41"
                    font.family: "monospace"
                    font.pixelSize: 11
                    font.letterSpacing: 3
                    opacity: 0.7
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    color: "#050505"
                    border.color: "#1a3a1a"
                    border.width: 1
                    radius: 2

                    Text {
                        id: statusLabel
                        anchors.fill: parent
                        anchors.margins: 10
                        text: "Initializing..."
                        color: "#00b32d"
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
        color: "#0d0d0d"
        border.color: "#00ff41"
        border.width: 1

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24

            Text {
                text: "QNX SDP 8.0"
                color: "#005c1a"
                font.family: "monospace"
                font.pixelSize: 11
            }
            Text {
                text: "RPi4B aarch64le"
                color: "#005c1a"
                font.family: "monospace"
                font.pixelSize: 11
            }
            Text {
                text: "Qt 6.10 | Wayland"
                color: "#005c1a"
                font.family: "monospace"
                font.pixelSize: 11
            }
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "CUHacking 2025"
            color: "#005c1a"
            font.family: "monospace"
            font.pixelSize: 11
        }
    }
}
