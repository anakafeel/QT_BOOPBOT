#pragma once
#include <QQuickImageProvider>
#include <QMutex>
#include <QImage>
#include <QObject>
#include <QThread>
#include <QTimer>
#include <atomic>
#include <screen/screen.h>

// Forward declare QNX camera types to avoid needing the real header
typedef int camera_handle_t;
typedef struct camera_buffer_t camera_buffer_t;

class CameraWorker : public QObject {
    Q_OBJECT
public:
    explicit CameraWorker(QObject* parent = nullptr);
    ~CameraWorker();

public slots:
    void start();
    void stop();

private slots:
    void pollFrame();

signals:
    void frameReady();
    void statusChanged(const QString& status);

public:
    QImage latestFrame();

private:
    void processFrame(camera_buffer_t* buffer);

    camera_handle_t m_handle = -1;
    QMutex m_mutex;
    QImage m_frame;
    std::atomic<bool> m_running{false};

    // Screen stream-mode members (replaces broken callback-based viewfinder)
    screen_context_t m_screenCtx = nullptr;
    screen_stream_t m_consumerStream = nullptr;
    screen_window_t m_window = nullptr;
    QTimer* m_pollTimer = nullptr;
};

class CameraImageProvider : public QQuickImageProvider {
public:
    explicit CameraImageProvider(CameraWorker* worker);
    QImage requestImage(const QString& id, QSize* size,
                        const QSize& requestedSize) override;
private:
    CameraWorker* m_worker;
};
