#include "camera_provider.h"
#include "camera_api.h"
#include <screen/screen.h>
#include <QDebug>
#include <QTimer>
#include <cstring>
#include <time.h>

// NV12 to RGB888 conversion
static QImage nv12ToRgb(const uint8_t* data, int width, int height) {
    QImage img(width, height, QImage::Format_RGB888);
    const uint8_t* y_plane = data;
    const uint8_t* uv_plane = data + width * height;
    for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
            int y = y_plane[row * width + col];
            int uv_idx = (row / 2) * width + (col & ~1);
            int u = uv_plane[uv_idx] - 128;
            int v = uv_plane[uv_idx + 1] - 128;
            int r = qBound(0, y + (int)(1.370705f * v), 255);
            int g = qBound(0, y - (int)(0.337633f * u) - (int)(0.698001f * v), 255);
            int b = qBound(0, y + (int)(1.732446f * u), 255);
            img.setPixel(col, row, qRgb(r, g, b));
        }
    }
    return img;
}

// RGBX8888/RGBA8888 direct copy (Screen buffer format, 4 bytes per pixel)
static QImage rgbxToRgb(const uint8_t* data, int width, int height, int stride) {
    QImage img(width, height, QImage::Format_RGB32);
    for (int row = 0; row < height; row++) {
        const uint8_t* src = data + row * stride;
        uint32_t* dst = reinterpret_cast<uint32_t*>(img.scanLine(row));
        for (int col = 0; col < width; col++) {
            dst[col] = qRgb(src[col*4], src[col*4+1], src[col*4+2]);
        }
    }
    return img;
}

CameraWorker::CameraWorker(QObject* parent) : QObject(parent) {}

CameraWorker::~CameraWorker() {
    stop();
}

void CameraWorker::start() {
    emit statusChanged("Setting up Screen context...");

    // Per official QNX docs ("Using stream mode"), the Screen context + window must be
    // created BEFORE camera_open()/camera_start_viewfinder() -- creating them after/concurrently
    // caused a confirmed crash (stream_cleanup err=22, ~12ms after first frame).
    if (screen_create_context(&m_screenCtx, 0) != 0) {
        emit statusChanged("screen_create_context failed");
        return;
    }
    if (screen_create_window(&m_window, m_screenCtx) != 0) {
        emit statusChanged("screen_create_window failed");
        return;
    }
    {
        int visible = 0;
        screen_set_window_property_iv(m_window, SCREEN_PROPERTY_VISIBLE, &visible);
    }
    screen_event_t ev;
    if (screen_create_event(&ev) != 0) {
        emit statusChanged("screen_create_event failed");
        return;
    }

    emit statusChanged("Opening camera...");
    camera_error_t err = camera_open(CAMERA_UNIT_1,
                                     CAMERA_MODE_RW | CAMERA_MODE_ROLL,
                                     &m_handle);
    if (err != CAMERA_EOK) {
        emit statusChanged(QString("camera_open failed: %1").arg(err));
        return;
    }
    err = camera_set_vf_mode(m_handle, (camera_vfmode_t)5);
    if (err != CAMERA_EOK) {
        emit statusChanged(QString("camera_set_vf_mode failed: %1").arg(err));
        camera_close(m_handle);
        return;
    }
    err = camera_private_set_vf_property(m_handle, CAMERA_IMGPROP_CREATEWINDOW, 0, -1);
    if (err != CAMERA_EOK) {
        emit statusChanged(QString("set CREATEWINDOW=0 failed: %1").arg(err));
        camera_close(m_handle);
        return;
    }
    err = camera_start_viewfinder(m_handle, nullptr, nullptr, nullptr);
    if (err != CAMERA_EOK) {
        emit statusChanged(QString("camera_start_viewfinder failed: %1").arg(err));
        camera_close(m_handle);
        return;
    }
    emit statusChanged("Waiting for stream handle...");
    screen_stream_t producerStream = nullptr;
    bool gotStream = false;
    for (int attempt = 0; attempt < 50 && !gotStream; attempt++) {
        int rc = screen_get_event(m_screenCtx, ev, 100);
        if (rc != 0) continue;
        int eventType = 0;
        screen_get_event_property_iv(ev, SCREEN_PROPERTY_TYPE, &eventType);
        if (eventType == SCREEN_EVENT_CREATE) {
            void* streamHandle = nullptr;
            if (screen_get_event_property_pv(ev, SCREEN_PROPERTY_STREAM, &streamHandle) == 0 && streamHandle) {
                producerStream = static_cast<screen_stream_t>(streamHandle);
                gotStream = true;
            }
        }
    }

    if (!gotStream) {
        emit statusChanged("Timed out waiting for camera stream");
        camera_stop_viewfinder(m_handle);
        camera_close(m_handle);
        return;
    }

    if (screen_create_stream(&m_consumerStream, m_screenCtx) != 0) {
        emit statusChanged("screen_create_stream failed");
        camera_stop_viewfinder(m_handle);
        camera_close(m_handle);
        return;
    }

    int rc = -1;
    for (int attempt = 0; attempt < 20 && rc != 0; attempt++) {
        rc = screen_consume_stream_buffers(m_consumerStream, 0, producerStream);
        if (rc != 0) {
            struct timespec ts { 0, 100L * 1000000L };
            nanosleep(&ts, nullptr);
        }
    }
    if (rc != 0) {
        emit statusChanged("screen_consume_stream_buffers failed");
        camera_stop_viewfinder(m_handle);
        camera_close(m_handle);
        return;
    }

    m_running = true;
    emit statusChanged("Camera streaming");

    m_pollTimer = new QTimer();
    m_pollTimer->setInterval(33);
    connect(m_pollTimer, &QTimer::timeout, this, &CameraWorker::pollFrame);
    m_pollTimer->start();
}

void CameraWorker::pollFrame() {
    if (!m_running) return;

    screen_buffer_t sbuf = nullptr;
    int count = 0;
    int* dirty = nullptr;
    int rc = screen_acquire_buffer(&sbuf, m_consumerStream, &count, &dirty, nullptr, 0);
    if (rc != 0 || !sbuf) {
        return;
    }

    int format = 0, stride = 0;
    int size[2] = {0, 0};
    void* ptr = nullptr;
    screen_get_buffer_property_iv(sbuf, SCREEN_PROPERTY_FORMAT, &format);
    screen_get_buffer_property_iv(sbuf, SCREEN_PROPERTY_STRIDE, &stride);
    screen_get_buffer_property_iv(sbuf, SCREEN_PROPERTY_BUFFER_SIZE, size);
    screen_get_buffer_property_pv(sbuf, SCREEN_PROPERTY_POINTER, &ptr);

    if (ptr && size[0] > 0 && size[1] > 0) {
        QImage img;
        if (format == SCREEN_FORMAT_NV12) {
            img = nv12ToRgb(static_cast<const uint8_t*>(ptr), size[0], size[1]);
        } else {
            img = rgbxToRgb(static_cast<const uint8_t*>(ptr), size[0], size[1], stride);
        }
        if (!img.isNull()) {
            QMutexLocker lock(&m_mutex);
            m_frame = img;
        }
        emit frameReady();
    }

    screen_release_buffer(sbuf);
}

void CameraWorker::stop() {
    m_running = false;
    if (m_pollTimer) {
        m_pollTimer->stop();
        delete m_pollTimer;
        m_pollTimer = nullptr;
    }
    if (m_handle >= 0) {
        camera_stop_viewfinder(m_handle);
        camera_close(m_handle);
        m_handle = -1;
    }
}

QImage CameraWorker::latestFrame() {
    QMutexLocker lock(&m_mutex);
    return m_frame;
}

CameraImageProvider::CameraImageProvider(CameraWorker* worker)
    : QQuickImageProvider(QQuickImageProvider::Image)
    , m_worker(worker) {}

QImage CameraImageProvider::requestImage(const QString&, QSize* size,
                                          const QSize& requestedSize) {
    QImage img = m_worker->latestFrame();
    if (img.isNull()) {
        img = QImage(640, 480, QImage::Format_RGB888);
        img.fill(QColor("#0a0a0a"));
    }
    if (size) *size = img.size();
    if (requestedSize.isValid() && requestedSize != img.size()) {
        return img.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    return img;
}
