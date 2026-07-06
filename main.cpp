#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "camera_provider.h"
#include "ros_bridge.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    CameraWorker* worker    = new CameraWorker();
    RosBridge*    rosBridge = new RosBridge();

    QQmlApplicationEngine engine;
    engine.addImageProvider("camera", new CameraImageProvider(worker));
    engine.rootContext()->setContextProperty("cameraRelay", worker);
    engine.rootContext()->setContextProperty("rosBridge",   rosBridge);

    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty()) return -1;

    worker->start();
    return app.exec();
}
