#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "camera_provider.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    CameraWorker* worker = new CameraWorker();

    QQmlApplicationEngine engine;
    engine.addImageProvider("camera", new CameraImageProvider(worker));
    engine.rootContext()->setContextProperty("cameraRelay", worker);

    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty()) return -1;

    // Start camera after QML is loaded
    worker->start();

    return app.exec();
}
