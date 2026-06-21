#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QThread>
#include <QObject>
#include <QString>
#include "camera_provider.h"

// Relay lives on the main thread and forwards signals from the worker thread
class CameraRelay : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
public:
    explicit CameraRelay(QObject* parent = nullptr) : QObject(parent) {}
    QString status() const { return m_status; }

public slots:
    void onStatusChanged(const QString& s) {
        m_status = s;
        emit statusChanged(s);
    }
    void onFrameReady() {
        emit frameReady();
    }

signals:
    void frameReady();
    void statusChanged(const QString& status);

private:
    QString m_status;
};

#include "main.moc"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    CameraWorker* worker = new CameraWorker();
    CameraImageProvider* provider = new CameraImageProvider(worker);
    CameraRelay* relay = new CameraRelay();

    QThread* camThread = new QThread();
    worker->moveToThread(camThread);

    // Connect worker signals to relay slots via queued connection (thread safe)
    QObject::connect(worker, &CameraWorker::frameReady,
                     relay, &CameraRelay::onFrameReady,
                     Qt::QueuedConnection);
    QObject::connect(worker, &CameraWorker::statusChanged,
                     relay, &CameraRelay::onStatusChanged,
                     Qt::QueuedConnection);

    QQmlApplicationEngine engine;
    engine.addImageProvider("camera", provider);
    engine.rootContext()->setContextProperty("cameraRelay", relay);

    engine.load(QUrl::fromLocalFile(
        QCoreApplication::applicationDirPath() + "/Main.qml"
    ));

    if (engine.rootObjects().isEmpty())
        return -1;

    QObject::connect(camThread, &QThread::started, worker, &CameraWorker::start);
    camThread->start();

    int ret = app.exec();

    worker->stop();
    camThread->quit();
    camThread->wait();
    delete camThread;
    delete worker;
    delete relay;
    return ret;
}
