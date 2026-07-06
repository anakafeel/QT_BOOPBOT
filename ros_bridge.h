#pragma once
#include <QObject>
#include <QString>
#include <QLocalSocket>
#include <QTimer>

class RosBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString botStatus   READ botStatus   NOTIFY botStatusChanged)
    Q_PROPERTY(float   battery     READ battery     NOTIFY batteryChanged)
    Q_PROPERTY(float   speed       READ speed       NOTIFY speedChanged)
    Q_PROPERTY(QString diagnostics READ diagnostics NOTIFY diagnosticsChanged)
    Q_PROPERTY(bool    connected   READ connected   NOTIFY connectedChanged)

public:
    explicit RosBridge(QObject* parent = nullptr);

    QString botStatus()   const { return m_botStatus; }
    float   battery()     const { return m_battery; }
    float   speed()       const { return m_speed; }
    QString diagnostics() const { return m_diagnostics; }
    bool    connected()   const { return m_connected; }

signals:
    void botStatusChanged();
    void batteryChanged();
    void speedChanged();
    void diagnosticsChanged();
    void connectedChanged();

private slots:
    void tryConnect();
    void onReadyRead();
    void onConnected();
    void onDisconnected();

private:
    void processMessage(const QByteArray& line);

    QLocalSocket* m_socket{nullptr};
    QTimer*       m_retryTimer{nullptr};
    QByteArray    m_buffer;

    QString m_botStatus{"Waiting..."};
    float   m_battery{0.0f};
    float   m_speed{0.0f};
    QString m_diagnostics{"No data yet"};
    bool    m_connected{false};
};
