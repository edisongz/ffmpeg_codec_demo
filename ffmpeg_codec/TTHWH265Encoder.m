//
//  TTHWH265Encoder.m
//  ffmpeg_codec_demo
//
//  Created by 蒋益杰 on 2017/11/5.
//  Copyright © 2017年 t. All rights reserved.
//

#import "TTHWH265Encoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface TTHWH265Encoder () {
    VTCompressionSessionRef compressionSession;
    NSInteger frameCount;
    NSData *sps;
    NSData *pps;
    FILE *fp;
    BOOL enabledWriteVideoFile;
    
    NSInteger _currentVideoBitRate;
    
    int64_t videoBitRate;
    int videoFrameRate;
    int videoMaxFrameRate;
    int videoMinFrameRate;
    int64_t videoMaxBitRate;
    int64_t videoMinBitRate;
}

@end

@implementation TTHWH265Encoder

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSLog(@"USE LFHardwareVideoEncoder");
        [self resetCompressionSession];
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        videoBitRate = 600 * 1000;
        videoFrameRate = 24;
        videoMaxFrameRate = 24;
        videoMinFrameRate = 12;
        videoMaxBitRate = 720 * 1000;
        videoMinBitRate = 500 * 1000;
        
#ifdef DEBUG
        enabledWriteVideoFile = NO;
        [self initForFilePath];
#endif
    }
    return self;
}

#pragma mark - encode video: yuv to NSData
- (void)encode:(CMSampleBufferRef)sampleBuffer {
    
}

- (void)resetCompressionSession {
    if (compressionSession) {
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(compressionSession);
        CFRelease(compressionSession);
        compressionSession = NULL;
    }
    
    OSStatus status = VTCompressionSessionCreate(NULL, 480, 640, kCMVideoCodecType_HEVC, NULL, NULL, NULL, VideoCompressonOutputCallback, (__bridge void *)self, &compressionSession);
    if (status != noErr) {
        return;
    }
    
    _currentVideoBitRate = (NSInteger)videoBitRate;
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(videoFrameRate * 2));
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@((videoFrameRate * 2)/videoFrameRate));
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(videoFrameRate));
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(videoBitRate));
    NSArray *limit = @[@(videoBitRate * 1.5/8), @(1)];
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    if (@available(iOS 11.0, *)) {
        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_HEVC_Main_AutoLevel);
    } else {
        // Fallback on earlier versions
        VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
    }
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanTrue);
//    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    VTCompressionSessionPrepareToEncodeFrames(compressionSession);
    
}

- (void)setVideoBitRate:(NSInteger)videoBitRate {

    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(videoBitRate));
    NSArray *limit = @[@(videoBitRate * 1.5/8), @(1)];
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    _currentVideoBitRate = videoBitRate;
}

- (NSInteger)videoBitRate {
    return _currentVideoBitRate;
}

- (void)dealloc {
    if (compressionSession != NULL) {
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);

        VTCompressionSessionInvalidate(compressionSession);
        CFRelease(compressionSession);
        compressionSession = NULL;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -- LFVideoEncoder
- (void)encodeVideoData:(CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp {
//    if(_isBackGround) return;
    frameCount++;
    CMTime presentationTimeStamp = CMTimeMake(frameCount, (int32_t)videoFrameRate);
    VTEncodeInfoFlags flags;
    CMTime duration = CMTimeMake(1, (int32_t)videoFrameRate);

    NSDictionary *properties = nil;
    if (frameCount % (int32_t)videoFrameRate*2 == 0) {
        properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
    }
    NSNumber *timeNumber = @(timeStamp);

    OSStatus status = VTCompressionSessionEncodeFrame(compressionSession, pixelBuffer, presentationTimeStamp, duration, (__bridge CFDictionaryRef)properties, (__bridge_retained void *)timeNumber, &flags);
    if(status != noErr){
        [self resetCompressionSession];
    }
}

- (void)stopEncoder {
    VTCompressionSessionCompleteFrames(compressionSession, kCMTimeIndefinite);
}

- (void)setDelegate:(id<TTVideoEncodingDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark -- Notification
//- (void)willEnterBackground:(NSNotification*)notification{
//    _isBackGround = YES;
//}
//
//- (void)willEnterForeground:(NSNotification*)notification{
//    [self resetCompressionSession];
//    _isBackGround = NO;
//}

#pragma mark -- VideoCallBack
static void VideoCompressonOutputCallback(void *VTref, void *VTFrameRef, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer){
    if (!sampleBuffer) return;
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!array) return;
    CFDictionaryRef dic = (CFDictionaryRef)CFArrayGetValueAtIndex(array, 0);
    if (!dic) return;

    BOOL keyframe = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    uint64_t timeStamp = [((__bridge_transfer NSNumber *)VTFrameRef) longLongValue];

    TTHWH265Encoder *videoEncoder = (__bridge TTHWH265Encoder *)VTref;
    if (status != noErr) {
        return;
    }

    // 关键帧且 sps空
    if (keyframe && !videoEncoder->sps) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);

        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        
        if (@available(iOS 11.0, *)) {
            OSStatus statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
            if (statusCode == noErr) {
                size_t pparameterSetSize, pparameterSetCount;
                const uint8_t *pparameterSet;
                OSStatus statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
                if (statusCode == noErr) {
                    videoEncoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                    videoEncoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                    
                    if (videoEncoder->enabledWriteVideoFile) {
                        NSMutableData *data = [[NSMutableData alloc] init];
                        uint8_t header[] = {0x00, 0x00, 0x00, 0x01};
                        [data appendBytes:header length:4];
                        [data appendData:videoEncoder->sps];
                        [data appendBytes:header length:4];
                        [data appendData:videoEncoder->pps];
                        fwrite(data.bytes, 1, data.length, videoEncoder->fp);
                    }
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }

    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);

            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);

            NSData *encodedData = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
//            LFVideoFrame *videoFrame = [LFVideoFrame new];
//            videoFrame.timestamp = timeStamp;
//            videoFrame.data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
//            videoFrame.isKeyFrame = keyframe;
//            videoFrame.sps = videoEncoder->sps;
//            videoFrame.pps = videoEncoder->pps;

//            if (videoEncoder.delegate && [videoEncoder.delegate respondsToSelector:@selector(videoEncoder:videoFrame:)]) {
//                [videoEncoder.delegate videoEncoder:videoEncoder videoFrame:videoFrame];
//            }
            
            if (videoEncoder.delegate && [videoEncoder.delegate respondsToSelector:@selector(videoEncoder:encodedData:)]) {
                [videoEncoder.delegate videoEncoder:videoEncoder encodedData:encodedData];
            }

            if (videoEncoder->enabledWriteVideoFile) {
                NSMutableData *data = [[NSMutableData alloc] init];
                if (keyframe) {
                    uint8_t header[] = {0x00, 0x00, 0x00, 0x01};
                    [data appendBytes:header length:4];
                } else {
                    uint8_t header[] = {0x00, 0x00, 0x01};
                    [data appendBytes:header length:3];
                }
                [data appendData:encodedData];

                fwrite(data.bytes, 1, data.length, videoEncoder->fp);
            }

            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

- (void)initForFilePath {
    NSString *path = [self GetFilePathByfileName:@"demo.h265"];
    NSLog(@"%@", path);
    self->fp = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "wb");
}

- (NSString *)GetFilePathByfileName:(NSString*)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return writablePath;
}

@end
