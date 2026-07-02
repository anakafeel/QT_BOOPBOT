#include "camera_provider.h"
#include "camera_api.h"
#include <QDebug>
#include <cstring>

// NV12 to RGB888 conversion (Pi4 + Pi Camera Module 3)
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

// RGB8888 direct copy
static QImage rgb8888ToRgb(const uint8_t* data, int width, int height, int stride) {
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

// YCBYCR (YUV 4:2:2 packed) to RGB888 conversion (Pi5 + Logitech C920)
// Pixel order: Y0, Cb, Y1, Cr per macro-pixel (2 pixels)
static QImage ycbycr422ToRgb(const uint8_t* data, int width, int height, int stride) {
    QImage img(width, height, QImage::Format_RGB888);
    for (int row = 0; row < height; row++) {
        const uint8_t* src = data + row * stride;
        uint8_t* dst = img.scanLine(row);
        for (int col = 0; col < width; col += 2) {
            int y0 = src[col * 2 + 0];
            int cb = src[col * 2 + 1] - 128;
            int y1 = src[col * 2 + 2];
            int cr = src[col * 2 + 3] - 128;
            // pixel 0
            dst[col*3+0] = qBound(0, y0 + (int)(1.402f * cr), 255);
            dst[col*3+1] = qBound(0, y0 - (int)(0.344f * cb) - (int)(0.714f * cr), 255);
            dst[col*3+2] = qBound(0, y0 + (int)(1.772f * cb), 255);
            // pixel 1
            dst[col*3+3] = qBound(0, y1 + (int)(1.402f * cr), 255);
            dst[col*3+4] = qBound(0, y1 - (int)(0.344f * cb) - (int)(0.714f * cr), 255);
            dst[col*3+5] = qBound(0, y1 + (int)(1.772f * cb), 255);
        }
    }
    return img;
}

CameraWorker::CameraWorker(QObject* parent) : QObject(parent) {}

CameraWorker::~CameraWorker() {
    stop();
}

void CameraWorker::viewfinderCallback(camera_handle_t handle,
                                       camera_buffer_t* buffer,
                                       void* arg) {
    Q_UNUSED(handle);
    CameraWorker* self = static_cast<CameraWorker*>(arg);
    if (self && self->m_running)
        self->processFrame(buffer);
}

void CameraWorker::processFrame(camera_buffer_t* buffer) {
    if (!buffer || !buffer->framebuf) return;
    QImage img;
    if (buffer->frametype == CAMERA_FRAMETYPE_NV12) {
        int w = buffer->framedesc.nv12.width;
        int h = buffer->framedesc.nv12.height;
        img = nv12ToRgb(buffer->framebuf, w, h);
    } else if (buffer->frametype == CAMERA_FRAMETYPE_RGB8888) {
        int w = buffer->framedesc.rgb8888.width;
        int h = buffer->framedesc.rgb8888.height;
        int stride = buffer->framedesc.rgb8888.stride;
        img = rgb8888ToRgb(buffer->framebuf, w, h, stride);
    } else if (buffer->frametype == CAMERA_FRAMETYPE_YCBYCR) {
        int w = buffer->framedesc.ycbycr.width;
        int h = buffer->framedesc.ycbycr.height;
        int stride = buffer->framedesc.ycbycr.stride;
        img = ycbycr422ToRgb(buffer->framebuf, w, h, stride);
    } else {
        img = QImage(640, 480, QImage::Format_RGB888);
        img.fill(Qt::darkGray);
    }
    if (!img.isNull()) {
        QMutexLocker lock(&m_mutex);
        m_frame = img;
    }
    m_frameSkip++;
    if (m_frameSkip % 3 == 0) emit frameReady();
}

void CameraWorker::start() {
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
    m_running = true;
    err = camera_start_viewfinder(m_handle,
                                  viewfinderCallback,
                                  nullptr,
                                  this);
    if (err != CAMERA_EOK) {
        m_running = false;
        emit statusChanged(QString("camera_start_viewfinder failed: %1").arg(err));
        camera_close(m_handle);
        return;
    }
    emit statusChanged("Camera streaming");
}

void CameraWorker::stop() {
    m_running = false;
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
