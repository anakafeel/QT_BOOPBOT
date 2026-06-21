#pragma once
#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef int camera_handle_t;
#define CAMERA_HANDLE_INVALID (-1)
typedef enum { CAMERA_UNIT_NONE=-1, CAMERA_UNIT_1=1, CAMERA_UNIT_2=2 } camera_unit_t;
#define CAMERA_MODE_RW   0x00000003
#define CAMERA_MODE_ROLL 0x00000010
typedef enum { CAMERA_EOK=0, CAMERA_EAGAIN=1, CAMERA_EINVAL=2, CAMERA_ENODEV=3, CAMERA_EMFILE=4, CAMERA_EBADF=5, CAMERA_EACCESS=6, CAMERA_ENODATA=7, CAMERA_ENOENT=8, CAMERA_ENOMEM=9, CAMERA_EOPNOTSUPP=10, CAMERA_ETIMEDOUT=11, CAMERA_EALREADY=12, CAMERA_EBUSY=13, CAMERA_ENOSPC=14, CAMERA_EUNINIT=15, CAMERA_EOPERR=16, CAMERA_EIOERR=17, CAMERA_ENOSYS=18, CAMERA_EPERM=19, CAMERA_ENOTSUP=20 } camera_error_t;
typedef enum { CAMERA_VFMODE_DEFAULT=0, CAMERA_VFMODE_VIDEO=1, CAMERA_VFMODE_PHOTO=2 } camera_vfmode_t;
typedef enum { CAMERA_FRAMETYPE_UNSPECIFIED=0, CAMERA_FRAMETYPE_NV12=1, CAMERA_FRAMETYPE_RGB8888=2, CAMERA_FRAMETYPE_RGB888=3, CAMERA_FRAMETYPE_GRAY8=4, CAMERA_FRAMETYPE_BAYER=6, CAMERA_FRAMETYPE_CBYCRY=7, CAMERA_FRAMETYPE_COMPRESSEDVIDEO=8, CAMERA_FRAMETYPE_COMPRESSEDAUDIO=9, CAMERA_FRAMETYPE_RGB565=10, CAMERA_FRAMETYPE_YCBCR420P=11, CAMERA_FRAMETYPE_YCBYCR=12, CAMERA_FRAMETYPE_YCRYCB=13, CAMERA_FRAMETYPE_CRYCBY=14 } camera_frametype_t;
typedef enum { CAMERA_IMGPROP_END=0, CAMERA_IMGPROP_WIDTH=1, CAMERA_IMGPROP_HEIGHT=2, CAMERA_IMGPROP_FORMAT=3, CAMERA_IMGPROP_FRAMERATE=4, CAMERA_IMGPROP_ROTATION=5, CAMERA_IMGPROP_CREATEWINDOW=11, CAMERA_IMGPROP_STRIDE=14 } camera_imgprop_t;
typedef enum { CAMERA_STATUS_UNKNOWN=0, CAMERA_STATUS_FOCUS_CHANGE=1, CAMERA_STATUS_POWERDOWN=2, CAMERA_STATUS_RESOURCENOTAVAIL=3 } camera_devstatus_t;
typedef struct { int width; int height; int stride; } camera_frame_nv12_t;
typedef struct { int width; int height; int stride; } camera_frame_rgb8888_t;
typedef struct { int width; int height; int stride; } camera_frame_rgb888_t;
typedef struct { int width; int height; int stride; } camera_frame_gray8_t;
typedef struct { int width; int height; int stride; } camera_frame_rgb565_t;
typedef struct { int width; int height; int stride; } camera_frame_ycbcr420p_t;
typedef struct { int width; int height; int stride; } camera_frame_ycbycr_t;
typedef struct { int width; int height; int stride; } camera_frame_ycrycb_t;
typedef struct { int width; int height; int stride; } camera_frame_crycby_t;
typedef struct { int width; int height; int stride; } camera_frame_unspecified_t;
typedef struct { int width; int height; int stride; } camera_frame_bayer_t;
typedef struct { int width; int height; int stride; } camera_frame_cbycry_t;
typedef struct { uint64_t bufsize; } camera_frame_compressedvideo_t;
typedef struct { uint64_t bufsize; } camera_frame_compressedaudio_t;
typedef struct { int width; int height; } camera_frame_roi_t;
typedef union { camera_frame_unspecified_t unspecified; camera_frame_nv12_t nv12; camera_frame_rgb8888_t rgb8888; camera_frame_rgb888_t rgb888; camera_frame_gray8_t gray8; camera_frame_bayer_t bayer; camera_frame_cbycry_t cbycry; camera_frame_compressedvideo_t compvid; camera_frame_compressedaudio_t compaud; camera_frame_rgb565_t rgb565; camera_frame_ycbcr420p_t ycbcr420p; camera_frame_ycbycr_t ycbycr; camera_frame_ycrycb_t ycrycb; camera_frame_crycby_t crycby; camera_frame_roi_t roi; camera_frame_nv12_t nv16; } camera_framedesc_t;
typedef struct camera_buffer_t { camera_frametype_t frametype; uint64_t framesize; uint8_t* framebuf; uint64_t framemetasize; void* framemeta; int64_t frametimestamp; int32_t frameorientation; camera_framedesc_t framedesc; } camera_buffer_t;
typedef void (*camera_vf_callback_t)(camera_handle_t, camera_buffer_t*, void*);
typedef void (*camera_status_callback_t)(camera_handle_t, camera_devstatus_t, uint16_t, void*);
camera_error_t camera_open(camera_unit_t unit, uint32_t mode, camera_handle_t* handle);
camera_error_t camera_close(camera_handle_t handle);
camera_error_t camera_set_vf_mode(camera_handle_t handle, camera_vfmode_t mode);
camera_error_t camera_private_set_vf_property(camera_handle_t handle, ...);
camera_error_t camera_private_get_vf_property(camera_handle_t handle, ...);
camera_error_t camera_start_viewfinder(camera_handle_t handle, camera_vf_callback_t vf_cb, camera_status_callback_t status_cb, void* arg);
camera_error_t camera_stop_viewfinder(camera_handle_t handle);
camera_error_t camera_get_supported_cameras(uint32_t numasked, uint32_t* numsupported, camera_unit_t* cameras);
#ifdef __cplusplus
}
#endif
