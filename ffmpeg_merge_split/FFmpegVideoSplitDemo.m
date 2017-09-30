//
//  FFmpegVideoSplitDemo.m
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/9/30.
//  Copyright © 2017年 t. All rights reserved.
//

#import "FFmpegVideoSplitDemo.h"
#import <CoreMedia/CoreMedia.h>

#import <libavformat/avformat.h>
#import <string.h>

static int set_output_header(AVFormatContext *ifmt_ctx, AVFormatContext *ofmt_ctx,
                             const char *in_filename, const char *out_filename) {
    if (ifmt_ctx == NULL || ofmt_ctx == NULL || in_filename == NULL || out_filename == NULL) {
        return -1;
    }
    AVOutputFormat *ofmt = ofmt_ctx->oformat;
    int ret;
    
    for (int i = 0; i < ifmt_ctx->nb_streams; ++i) {
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
        if (!out_stream) {
            return ret;
        }
        
        ret = avcodec_copy_context(out_stream->codec, in_stream->codec);
        if (ret < 0) {
            return ret;
        }
        out_stream->codec->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
            out_stream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
        }
    }
    
    if (!(ofmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&ofmt_ctx->pb, out_filename, AVIO_FLAG_WRITE);
        if (ret < 0) {
            return ret;
        }
    }
    ret = avformat_write_header(ofmt_ctx, NULL);
    if (ret < 0) {
        return ret;
    }
    return 0;
}

static int splitVideo(const char *in_filename, const char *out_filename, uint32_t splitSeconds) {
    AVPacket readPacket, splitKeyPacket;
    AVOutputFormat *ofmt = NULL;
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx = NULL;
    int ret, video_index = 0;
    
    if ((ret = avformat_open_input(&ifmt_ctx, in_filename, 0, 0)) < 0) {
        fprintf(stderr, "Could not open input file '%s'", in_filename);
        return ret;
    }
    if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
        fprintf(stderr, "Failed to retrieve input stream information");
        avformat_close_input(&ifmt_ctx);
        return ret;
    }
    
    //获取视频index
    for (int i = 0; i < ifmt_ctx->nb_streams; i++) {
        AVStream *in_stream = ifmt_ctx->streams[i];
        if (in_stream->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_index = i;
        }
    }
    int den = ifmt_ctx->streams[video_index]->r_frame_rate.den;
    int num = ifmt_ctx->streams[video_index]->r_frame_rate.num;
    float fps = num / (float)den;
    uint32_t splitVideoSize = fps * splitSeconds;
    
    //获取后缀
    NSString *outFilename = [[NSString alloc] initWithUTF8String:out_filename];
    NSArray *components = [outFilename componentsSeparatedByString:@"."];
    NSString *suffix = [components lastObject];
    NSString *name = components.firstObject;
    
    avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_filename);
    if (!ofmt_ctx) {
        fprintf(stderr, "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
//        goto end;
        return ret;
    }
    ofmt = ofmt_ctx->oformat;
    set_output_header(ifmt_ctx, ofmt_ctx, in_filename, out_filename);
    
    // 关键帧时间数组
    NSMutableArray *keyframePosArray = [[NSMutableArray alloc] init];
    uint64_t frame_index = 0;
    uint64_t keyFrame_index = 0;
    int frameCount = 0;
    //读取分割点附近的关键帧位置
    while (1)
    {
        ++frame_index;
        ret = av_read_frame(ifmt_ctx, &readPacket);
        if (ret < 0)
        {
            break;
        }
        //过滤，只处理视频流
        if (readPacket.stream_index == video_index){

            ++frameCount;
            if (readPacket.flags&AV_PKT_FLAG_KEY)
            {
                keyFrame_index = frame_index;
            }
            if (frameCount>splitVideoSize)
            {
                [keyframePosArray addObject:@(keyFrame_index)];
                frameCount = 0;
            }
        }
        av_packet_unref(&readPacket);
    }
    
end:
    avformat_close_input(&ifmt_ctx);
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE)) {
        avio_closep(&ofmt_ctx->pb);
    }
    avformat_free_context(ofmt_ctx);
    if (ret < 0 && ret != AVERROR_EOF) {
        fprintf(stderr, "Error occurred: %s\n", av_err2str(ret));
        return 1;
    }
    return 0;
}

@interface FFmpegVideoSplitDemo ()

@property (nonatomic, strong) NSMutableArray *keyframePosArray;

@end

@implementation FFmpegVideoSplitDemo

- (instancetype)init
{
    self = [super init];
    if (self) {
        av_register_all();
        _keyframePosArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)splitVideo:(CMTime)time {
    
}

@end
