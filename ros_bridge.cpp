#include "ros_bridge.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>

#define SOCKET_PATH "/tmp/boopbot_bridge.sock"
#define RETRY_MS    2000

RosBridge::RosBridge(QObject* parent) : QObject(parent) {
    m_socket = new QLocalSocket(this);
    connect(m_socket, &QLocalSocket::connected,    this, &RosBridge::onConnected);
    connect(m_socket, &QLocalSocket::disconnected, this, &RosBridge::onDisconnected);
    connect(m_socket, &QLocalSocket::readyRead,    this, &RosBridge::onReadyRead);

    m_retryTimer = new QTimer(this);
    m_retryTimer->setInterval(RETRY_MS);
    connect(m_retryTimer, &QTimer::timeout, this, &RosBridge::tryConnect);
    m_retryTimer->start();

    tryConnect();
}

void RosBridge::tryConnect() {
    if (m_socket->state() == QLocalSocket::UnconnectedState) {
        m_socket->connectToServer(SOCKET_PATH);
    }
}

void RosBridge::onConnected() {
    m_retryTimer->stop();
    m_connected = true;
    emit connectedChanged();
    qDebug() << "RosBridge: connected to bridge socket";
}

void RosBridge::onDisconnected() {
    m_connected = false;
    m_botStatus = "Disconnected";
    emit connectedChanged();
    emit botStatusChanged();
    m_retryTimer->start();
    qDebug() << "RosBridge: disconnected, retrying...";
}

void RosBridge::onReadyRead() {
    m_buffer += m_socket->readAll();
    while (true) {
        int idx = m_buffer.indexOf('\n');
        if (idx < 0) break;
        QByteArray line = m_buffer.left(idx);
        m_buffer = m_buffer.mid(idx + 1);
        processMessage(line);
    }
}

void RosBridge::processMessage(const QByteArray& line) {
    QJsonDocument doc = QJsonDocument::fromJson(line);
    if (!doc.isObject()) return;
    QJsonObject obj = doc.object();
    QString type = obj["type"].toString();

    if (type == "bot_status") {
        m_botStatus = obj["value"].toString();
        emit botStatusChanged();
    } else if (type == "battery") {
        m_battery = (float)obj["value"].toDouble();
        emit batteryChanged();
    } else if (type == "speed") {
        m_speed = (float)obj["value"].toDouble();
        emit speedChanged();
    } else if (type == "diagnostics") {
        m_diagnostics = obj["value"].toString();
        emit diagnosticsChanged();
    }
}
