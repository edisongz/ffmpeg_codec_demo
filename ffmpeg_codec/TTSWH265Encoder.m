//
//  TTSWH265Encodeer.m
//  ffmpeg_codec_demo
//
//  Created by 蒋益杰 on 2017/11/4.
//  Copyright © 2017年 t. All rights reserved.
//

#import "TTSWH265Encoder.h"
#import <libavcodec/avcodec.h>
#import <libavformat/avformat.h>
#import <libswscale/swscale.h>
#import <libavutil/opt.h>
#import <libavutil/imgutils.h>

//static int flush_encoder(AVFormatContext *fmt_ctx,unsigned int stream_index)
//{
//    int ret;
//    int got_frame;
//    AVPacket enc_pkt;
//    if (!(fmt_ctx->streams[stream_index]->codec->codec->capabilities &
//          CODEC_CAP_DELAY))
//        return 0;
//    while (1) {
//        printf("Flushing stream #%u encoder\n", stream_index);
//        //ret = encode_write_frame(NULL, stream_index, &got_frame);
//        enc_pkt.data = NULL;
//        enc_pkt.size = 0;
//        av_init_packet(&enc_pkt);
//        ret = avcodec_encode_video2 (fmt_ctx->streams[stream_index]->codec, &enc_pkt,
//                                     NULL, &got_frame);
//        av_frame_free(NULL);
//        if (ret < 0)
//            break;
//        if (!got_frame){
//            ret=0;
//            break;
//        }
//        printf("Succeed to encode 1 frame! 编码成功1帧！\n");
//        /* mux encoded frame */
//        ret = av_write_frame(fmt_ctx, &enc_pkt);
//        if (ret < 0)
//            break;
//    }
//    return ret;
//}

@interface TTSWH265Encoder () {
    AVStream *_video_st;
    AVCodecContext *_pCodecCtx;
    AVCodec *_pCodecH265;
    
    AVFrame *_picture;
    int size;
    int pts;
    
    uint32_t _bitrate;
    uint32_t _framerate;
    CGSize _resolution;
}


@end

@implementation TTSWH265Encoder

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self _setup];
    }
    return self;
}

- (void)dealloc
{
    if (_pCodecCtx) {
        avcodec_free_context(&_pCodecCtx);
        _pCodecCtx = NULL;
    }
    
    if (_picture) {
        av_frame_free(&_picture);
        _picture = NULL;
    }
}

- (void)_setup {
    avcodec_register_all();         //注册编解码器
    _pCodecCtx = avcodec_alloc_context3(_pCodecH265);//函数用于分配一个AVCodecContext并设置默认值，如果失败返回NULL，并可用av_free()进行释放
    if (_pCodecCtx == NULL) {
        fprintf(stderr, "h265 codec context alloc failed.\n");
        exit(1);
    }
//    _nDataLen = 0;
    
    _pCodecCtx->codec_id = AV_CODEC_ID_HEVC;
    _pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    _pCodecCtx->pix_fmt = AV_PIX_FMT_YUV420P;
    _pCodecCtx->width = 480;
    _pCodecCtx->height = 640;
    _pCodecCtx->time_base.num = 1;
    _pCodecCtx->time_base.den = 25;
    _pCodecCtx->bit_rate = 400000;
    _pCodecCtx->gop_size= 250;
    //H264
    //pCodecCtx->me_range = 16;
    //pCodecCtx->max_qdiff = 4;
    //pCodecCtx->qcompress = 0.6;
    _pCodecCtx->qmin = 10;
    _pCodecCtx->qmax = 51;
    
    //Optional Param
//    _pCodecCtx->max_b_frames=3;
    
    // Set Option
    AVDictionary *param = 0;
    //H.265
    if(_pCodecCtx->codec_id == AV_CODEC_ID_H265){
        av_dict_set(&param, "x265-params", "qp=20", 0);
        av_dict_set(&param, "preset", "ultrafast", 0);
        av_dict_set(&param, "tune", "zero-latency", 0);
    }
    
    _pCodecH265 = avcodec_find_decoder(AV_CODEC_ID_H265);     //查找h264解码器
    if (!_pCodecH265)
    {
        fprintf(stderr, "h265 codec not found\n");
        exit(1);
    }
    if (_pCodecH265->capabilities & CODEC_CAP_TRUNCATED)
        _pCodecCtx->flags |= CODEC_FLAG_TRUNCATED;    /* we do not send complete frames */
    if (avcodec_open2(_pCodecCtx, _pCodecH265, &param) < 0) {
        fprintf(stderr, "Could not open codec.\n");
        exit(1);
    }
    
    _picture = av_frame_alloc();
    _picture->format = _pCodecCtx->pix_fmt;
    _picture->width = _pCodecCtx->width;
    _picture->height = _pCodecCtx->height;
//    size = av_image_get_buffer_size(AV_PIX_FMT_YUV420P, 480, 640, 1);
    
    
}

#pragma mark - Public Methods
- (void)setDelegate:(id<TTVideoEncodingDelegate>)delegate {
    _delegate = delegate;
}

- (void)encode:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    uint8_t *baseAddr0 = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    uint8_t *baseAddr1 = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    int nal_count;
    AVPacket pkt;
    int f_size = _pCodecCtx->width * _pCodecCtx->height;
    av_new_packet(&pkt, f_size);
    
    // copy yuv数据进AVFrame
    memcpy(_picture->data[0], baseAddr0, f_size);
    uint8_t *pdst1 = _picture->data[1];
    uint8_t *pdst2 = _picture->data[2];
    // yuv420
    // from: http://www.cnblogs.com/azraelly/archive/2013/01/01/2841269.htm
    // 此处可以用libyuv 中的arm neon优化，对yuv序列进行预处理，后续处理
    for (int i = 0; i < f_size / 4; i++) {
        *pdst1++ = *baseAddr1++;
        *pdst2++ = *baseAddr1++;
    }
    _picture->pts = ++pts;
    
    int ret = avcodec_encode_video2(_pCodecCtx, &pkt, _picture, &nal_count);
    if (ret < 0) {
        printf("Failed to encode! 编码错误！\n");
        return;
    }
    
    if (nal_count > 0) {
        NSData *encodedData = [NSData dataWithBytes:pkt.data length:pkt.size];
        if ([_delegate respondsToSelector:@selector(videoEncoder:encodedData:)]) {
            [_delegate videoEncoder:self encodedData:encodedData];
        }
    }
//    av_packet_unref(&pkt);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

@end
