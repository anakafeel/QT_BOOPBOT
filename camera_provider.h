#pragma once
#include <QQuickImageProvider>
#include <QMutex>
#include <QImage>
#include <QObject>
#include <QThread>
#include <QStringList>
#include <atomic>
#include "camera_api.h"

class CameraWorker : public QObject {
    Q_OBJECT
public:
    explicit CameraWorker(QObject* parent = nullptr);
    ~CameraWorker();

public slots:
    void start();
    void stop();
    void capturePhoto();
    QStringList getPhotoList();

signals:
    void frameReady();
    void statusChanged(const QString& status);
    void photoCaptured(const QString& path);
    void photoListChanged(const QStringList& photos);

public:
    QImage latestFrame();

private:
    static void viewfinderCallback(camera_handle_t handle,
                                   camera_buffer_t* buffer,
                                   void* arg);
    void processFrame(camera_buffer_t* buffer);
    void ensurePhotoDirExists();

    camera_handle_t m_handle = CAMERA_HANDLE_INVALID;
    QMutex m_mutex;
    QImage m_frame;
    std::atomic<bool> m_running{false};
    int m_frameSkip{0};
    QString m_photoDir{"/data/photos"};
};

class CameraImageProvider : public QQuickImageProvider {
public:
    explicit CameraImageProvider(CameraWorker* worker);
    QImage requestImage(const QString& id, QSize* size,
                        const QSize& requestedSize) override;
private:
    CameraWorker* m_worker;
};
