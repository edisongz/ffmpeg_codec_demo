//
//  TTx264VideoEncoder.m
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/9/8.
//  Copyright © 2017年 t. All rights reserved.
//

#import "TTx264VideoEncoder.h"
#import <x264.h>

@interface TTx264VideoEncoder () {
    x264_param_t *_x264Param;
    x264_picture_t *_x264Pic;
    x264_t *_x264Encoder;
    x264_nal_t  *_x264Nal;
    int _previous_nal_size;
    unsigned  char *_pNal;
    FILE *_fp;
    unsigned char _szBodyBuffer[1024*32];
    
    uint32_t _bitrate;
    uint32_t _framerate;
    CGSize _resolution;
}

/**
 设置参数
 */
- (void)setupX264;

@end

@implementation TTx264VideoEncoder

- (instancetype)init
{
    self = [super init];
    if (self) {
        _bitrate = 256;
        _framerate = 28;
        _resolution = CGSizeMake(480, 640);
        
        [self setupX264];
    }
    return self;
}

- (void)dealloc {
    if (_x264Param) {
        free(_x264Param);
        _x264Param = NULL;
    }
    
    if (_x264Pic) {
        free(_x264Pic);
        _x264Pic = NULL;
    }
    
    if (_x264Encoder) {
        x264_encoder_close(_x264Encoder);
        _x264Encoder = NULL;
    }
}

- (void)setupX264 {
    
    _x264Param = malloc(sizeof(x264_param_t));
    _x264Pic = malloc(sizeof(x264_picture_t));
    bzero(_x264Pic, sizeof(x264_picture_t));
    
    //预设
    x264_param_default_preset(_x264Param, "veryfast", "zerolatency");
    _x264Param->i_threads = 1;
    
    //分辨率
    _x264Param->i_width     = _resolution.width;  //set frame width
    _x264Param->i_height    = _resolution.height;  //set frame height
    _x264Param->i_frame_total = 0;
    _x264Param->i_keyint_max = 25;  //最大25帧，强制IDR
    _x264Param->b_intra_refresh = 1;
    _x264Param->i_level_idc = 21;
    
    _x264Param->b_annexb =1;        // start code : 0x00 0x00 0x00 0x01
    
    _x264Param->b_cabac = 0;
    _x264Param->i_bframe = 0;
    _x264Param->b_interlaced = 0;
    
    //reconfig
    _x264Param->rc.i_rc_method = X264_RC_ABR;//X264_RC_CQP
    _x264Param->rc.i_bitrate = _bitrate;
    _x264Param->rc.i_vbv_max_bitrate = (uint32_t)(_bitrate * 1.2);
    _x264Param->rc.i_vbv_buffer_size = _x264Param->rc.i_vbv_max_bitrate;
    
    _x264Param->i_fps_den = 1;
    _x264Param->i_fps_num = _framerate;
    _x264Param->i_timebase_den = _x264Param->i_fps_num;
    _x264Param->i_timebase_num = _x264Param->i_fps_den;
    
    _x264Param->i_csp = X264_CSP_I420;
    
    x264_param_apply_profile(_x264Param, "baseline");
    if((_x264Encoder =x264_encoder_open(_x264Param)) == NULL)
    {
        fprintf(stderr, "x264_encoder_open failed/n" );
        return ;
    }
    x264_picture_alloc(_x264Pic, X264_CSP_I420, _x264Param->i_width, _x264Param->i_height);
    _x264Pic->i_type =X264_TYPE_AUTO;
}

- (void)setDelegate:(id<TTVideoEncodingDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark - reset
- (void)resetBitrate:(uint32_t)bitrate {
    _bitrate = bitrate;
    _x264Param->rc.i_bitrate = _bitrate;
    _x264Param->rc.i_vbv_max_bitrate = (uint32_t)(_bitrate * 1.2);
    _x264Param->rc.i_vbv_buffer_size = _x264Param->rc.i_vbv_max_bitrate;
    x264_encoder_reconfig(_x264Encoder, _x264Param);
}

- (void)resetFramerate:(uint32_t)framerate {
    _framerate = framerate;
    
    _x264Param->i_fps_den = 1;
    _x264Param->i_fps_num = _framerate;
    _x264Param->i_timebase_den = _x264Param->i_fps_num;
    _x264Param->i_timebase_num = _x264Param->i_fps_den;
    x264_encoder_reconfig(_x264Encoder, _x264Param);
}

- (void)resetResolution:(CGSize)size {
    _resolution = size;
    _x264Param->i_width     = _resolution.width;
    _x264Param->i_height    = _resolution.height;
    x264_encoder_reconfig(_x264Encoder, _x264Param);
}

#pragma mark - encode
- (void)encode:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    uint8_t *baseAddr0 = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    uint8_t *baseAddr1 = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    int nal_count;
    x264_picture_t pic_out;
    x264_picture_init(&pic_out);
    memcpy(_x264Pic->img.plane[0], baseAddr0, _resolution.width * _resolution.height);
    
    uint8_t *pdst1 = _x264Pic->img.plane[1];
    uint8_t *pdst2 = _x264Pic->img.plane[2];
    // yuv420
    // from: http://www.cnblogs.com/azraelly/archive/2013/01/01/2841269.htm
    // 此处可以用libyuv 中的arm neon优化，对yuv序列进行预处理，后续处理
    for (int i = 0; i < 640 * 480 / 4; i++) {
        *pdst1++ = *baseAddr1++;
        *pdst2++ = *baseAddr1++;
    }
    
    if (x264_encoder_encode(_x264Encoder, &_x264Nal, &nal_count, _x264Pic, &pic_out) < 0) {
        fprintf(stderr, "x264_encoder_encode failed\n");
    }
    
    if (nal_count > 0) {
        for (int i = 0; i < nal_count; i++) {
            NSData *encodedData = [NSData dataWithBytes:_x264Nal[i].p_payload length:_x264Nal[i].i_payload];
            if ([_delegate respondsToSelector:@selector(videoEncoder:encodedData:)]) {
                [_delegate videoEncoder:self encodedData:encodedData];
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

@end
