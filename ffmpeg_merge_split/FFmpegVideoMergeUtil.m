//
//  FFmpegVideoMergeUtil.m
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/12/26.
//  Copyright © 2017年 t. All rights reserved.
//

#import "FFmpegVideoMergeUtil.h"

#import <libavformat/avformat.h>

static AVFormatContext *ifmt_ctx1;

static AVFormatContext *ofmt_ctx;
static AVOutputFormat *ofmt;

/**
 打开输入文件

 @param ifmt_ctx 格式
 @param filename 视频文件名
 @return res
 */
static int open_input_file(AVFormatContext **ifmt_ctx, const char *filename)
{
    if (!filename) {
        return -1;
    }
    int ret;
    *ifmt_ctx = NULL;
    if ((ret = avformat_open_input(ifmt_ctx, filename, NULL, NULL)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open input file\n");
        return ret;
    }
    if ((ret = avformat_find_stream_info(*ifmt_ctx, NULL)) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot find stream information\n");
        return ret;
    }
//    av_dump_format(*ifmt_ctx, 0, filename, 0);
    return ret;
}

/**
 alloc输出合并文件

 @param out_filename 合并视频文件名
 @return res
 */
static int open_output_file(const char *out_filename) {
    if (!out_filename) {
        return -1;
    }
    
    int ret = 0;
    ofmt_ctx = NULL;
    ofmt = NULL;
    avformat_alloc_output_context2(&ofmt_ctx, NULL, NULL, out_filename);
    if (!ofmt_ctx) {
        fprintf(stderr, "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
    }
    ofmt = ofmt_ctx->oformat;
    
    return ret;
}

/**
 copy input context to output context

 @param ifmt_ctx input context
 @return res
 */
static int copy_format_context(AVFormatContext *ifmt_ctx) {
    if (!ifmt_ctx) {
        return -1;
    }
    int ret;
    for (unsigned int i = 0; i < ifmt_ctx->nb_streams; i++) {
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVStream *out_stream = avformat_new_stream(ofmt_ctx, in_stream->codec->codec);
        if (!out_stream) {
            fprintf(stderr, "Failed allocating output stream\n");
            ret = AVERROR_UNKNOWN;
            break;
        }
        ret = avcodec_copy_context(out_stream->codec, in_stream->codec);
        if (ret < 0) {
            fprintf(stderr, "Failed to copy context from input to output stream codec context\n");
            break;
        }
        out_stream->codec->codec_tag = 0;
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
            out_stream->codec->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
    return ret;
}

static int merge_videos(NSArray<NSString *> *input_files, const char *output_file) {
    if (!input_files || !output_file) {
        return -1;
    }
    
    __block int ret = 0;
    
    __block int64_t stream_pts_0 = 0;
    __block int64_t stream_dts_0 = 0;
    
    __block int64_t stream_pts_1 = 0;
    __block int64_t stream_dts_1 = 0;
    
    __block int64_t next_start_v_pts = 0;
    [input_files enumerateObjectsUsingBlock:^(NSString * input_file, NSUInteger idx, BOOL * _Nonnull stop) {
        
        ret = open_input_file(&ifmt_ctx1, [input_file cStringUsingEncoding:NSASCIIStringEncoding]);
        if (ret < 0 || !ifmt_ctx1) {
            fprintf(stderr, "Error when opening input file1\n");
            *stop = YES;
        }
        
        if (idx == 0) {
            ret = open_output_file(output_file);
            if (ret < 0 || !ofmt_ctx) {
                fprintf(stderr, "Error when alloc output context\n");
                *stop = YES;
            }
            
            ret = copy_format_context(ifmt_ctx1);
            if (ret < 0) {
                fprintf(stderr, "Error when copying context.\n");
                *stop = YES;
            }
            
            // 打开输出文件
            if (!(ofmt->flags & AVFMT_NOFILE)) {
                ret = avio_open(&ofmt_ctx->pb, output_file, AVIO_FLAG_WRITE);
                if (ret < 0) {
                    fprintf(stderr, "Could not open output file '%s'", output_file);
                }
            }
            ret = avformat_write_header(ofmt_ctx, NULL);
            if (ret < 0) {
                fprintf(stderr, "Error occurred when opening output file\n");
                *stop = YES;
            }
        }
        
        AVPacket pkt;
        
        if (idx == 0) {
            // 第一段视频
            while (1) {
                AVStream *in_stream, *out_stream;
                ret = av_read_frame(ifmt_ctx1, &pkt);
                if (ret < 0) {
                    break;
                }
                in_stream  = ifmt_ctx1->streams[pkt.stream_index];
                out_stream = ofmt_ctx->streams[pkt.stream_index];
                
                pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
                pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
                pkt.duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
                pkt.pos = -1;
                
                if (pkt.stream_index == 0) {
                    stream_pts_0 = pkt.pts + pkt.duration;
                    stream_dts_0 = pkt.dts + pkt.duration;
                } else {
                    stream_pts_1 = pkt.pts + pkt.duration;
                    stream_dts_1 = pkt.dts + pkt.duration;
                }
                
                ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
                if (ret < 0) {
                    fprintf(stderr, "Error muxing packet\n");
                    break;
                }
                av_packet_unref(&pkt);
            }
        } else {
            // 非第一段视频
            while (1) {
                AVStream *in_stream, *out_stream;
                ret = av_read_frame(ifmt_ctx1, &pkt);
                if (ret < 0) {
                    break;
                }
                in_stream  = ifmt_ctx1->streams[pkt.stream_index];
                out_stream = ofmt_ctx->streams[pkt.stream_index];
                
                int64_t raw_pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
                int64_t raw_dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
                int64_t raw_duration = av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
                
                if (pkt.stream_index == 0) {
                    pkt.pts = next_start_v_pts + raw_pts;
                    pkt.dts = next_start_v_pts + raw_dts;
                    
                    stream_pts_0 = next_start_v_pts + raw_pts + raw_duration;
                    stream_dts_0 = next_start_v_pts + raw_dts + raw_duration;
                } else {
                    pkt.pts = stream_pts_1;
                    pkt.dts = stream_dts_1;
                    
                    stream_pts_1 += raw_duration;
                    stream_dts_1 += raw_duration;
                }
                pkt.duration = raw_duration;
                pkt.pos = -1;
                
                ret = av_interleaved_write_frame(ofmt_ctx, &pkt);
                if (ret < 0) {
                    fprintf(stderr, "Error muxing packet\n");
                    break;
                }
                av_packet_unref(&pkt);
            }
        }
        avformat_close_input(&ifmt_ctx1);
        next_start_v_pts = stream_pts_0;
    }];
    av_write_trailer(ofmt_ctx);
    
    /* close output */
    if (ofmt_ctx && !(ofmt->flags & AVFMT_NOFILE)) {
        avio_closep(&ofmt_ctx->pb);
    }
    avformat_free_context(ofmt_ctx);
    
    return 0;
}

@interface FFmpegVideoMergeUtil ()
{
    dispatch_queue_t _merge_video_queue;
}

@end

@implementation FFmpegVideoMergeUtil

- (instancetype)init
{
    self = [super init];
    if (self) {
        av_register_all();
        _merge_video_queue = dispatch_queue_create("com.ffmpeg_demo.merge_queue", NULL);
    }
    return self;
}

- (void)merge_videos:(NSArray<NSString *> *)paths output_file:(NSString *)output_file completion:(MergeCompletionBlock)completion {
    dispatch_sync(_merge_video_queue, ^{
        int ret = merge_videos(paths, [output_file cStringUsingEncoding:NSASCIIStringEncoding]);
        if (ret < 0) {
            NSLog(@"merge video error");
        } else {
            if (completion) {
                completion(output_file);
            }
        }
    });
}

@end
