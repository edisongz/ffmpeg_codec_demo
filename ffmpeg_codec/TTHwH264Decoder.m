//
//  H264StreamDecoder.m
//  testdemo
//
//  Created by jiang on 2017/6/21.
//  Copyright © 2017年 jiang. All rights reserved.
//

#import "TTHwH264Decoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import <UIKit/UIKit.h>

//暂时为4bytes
static const uint8_t g_StartCode[4] = {0x00, 0x00, 0x00, 0x01};

@interface TTHwH264Decoder (){
    VTDecompressionSessionRef decompressionSession;
    CMVideoFormatDescriptionRef _decoderFormatDescription;
    
    uint32_t _spsSize;
    uint32_t _ppsSize;
    
    uint8_t *_sps;
    uint8_t *_pps;
    
    //输入 数据 及 长度，外部输入
    uint8_t *_inputBuffer;
    NSInteger _inputSize;
    
    //解析出完整的 一帧 和 长度
    uint8_t *_packetBuffer;
    NSInteger _packetSize;
    
    //上次remaining data
    NSMutableData *_remainingData;
    NSInteger _remainingSize;
}

@property (nonatomic) BOOL isBackGround;

@end

@implementation TTHwH264Decoder

#pragma mark - life cycle
- (instancetype)init {
    if (self = [super init]) {
        
        _remainingData = [[NSMutableData alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    if (_packetBuffer) {
        free(_packetBuffer);
        _packetBuffer = NULL;
    }
    
    if (_sps) {
        free(_sps);
        _sps = NULL;
    }
    _spsSize = 0;
    
    if (_pps) {
        free(_pps);
        _pps = NULL;
    }
    _ppsSize = 0;
    
    if(_decoderFormatDescription) {
        CFRelease(_decoderFormatDescription);
        _decoderFormatDescription = NULL;
    }
    
    if (decompressionSession) {
        VTDecompressionSessionInvalidate(decompressionSession);
        CFRelease(decompressionSession);
        decompressionSession = NULL;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setDelegate:(id<TTVideoDecodingDelegate>)delegate {
    _delegate = delegate;
}

#pragma mark - notification
- (void)willEnterBackground:(NSNotification *)notification {
    _isBackGround = YES;
}

- (void)willEnterForeground:(NSNotification *)notification {
    _isBackGround = NO;
}

#pragma mark - processing network or local stream

/**
 处理接收到的流数据，不一定是完整的NALU
 后续用slab内存来处理 经常有分配释放的情况
 */
- (void)_splitH264StreamNALU {
    if (!_inputBuffer || _inputSize == 0) {
        return;
    }
    
    //暂定为4
    if (memcmp(_inputBuffer, g_StartCode, 4) == 0) {
        uint8_t *pstart = _inputBuffer + 4;
        uint8_t *const pend = _inputBuffer + _inputSize;
        
        while (pstart < pend) {
            if (memcmp(pstart - 3, g_StartCode, 4) == 0) {
                _packetSize = pstart - _inputBuffer - 3;
                
                if (_packetBuffer) {
                    free(_packetBuffer);
                    _packetBuffer = NULL;
                }
                _packetBuffer = realloc(_packetBuffer, _packetSize);
                if (!_packetBuffer) { // memory alloc failed
                    return;
                }
                
                memcpy(_packetBuffer, _inputBuffer, _packetSize);
                _inputBuffer += _packetSize;
                _inputSize -= _packetSize;
                
                //处理完整一帧
                [self _startDecodingNALUPacket];
            }
            pstart++;
        }
    } else {
//        if (!_remainingBuffer) {
//            NSLog(@"_remainingBuffer 暂时不能为空");
//            return;
//        }
        
        uint8_t *pStart = _inputBuffer;
        uint8_t *const pEnd = _inputBuffer + _inputSize;
        
        while (pStart < pEnd) {
            if (pStart - _inputBuffer >= 3 && memcmp(pStart - 3, g_StartCode, 4) == 0) {
                // 拼接上次数据
                _packetSize = pStart - _inputBuffer - 3 + _remainingSize;
                
                if (_packetBuffer) {
                    free(_packetBuffer);
                    _packetBuffer = NULL;
                }
                _packetBuffer = realloc(_packetBuffer, _packetSize);
                if (!_packetBuffer) { // memory alloc failed
                    return;
                }
                
                //copy 存量数据
                const uint8_t *remainingdata = [_remainingData bytes];
                memcpy(_packetBuffer, remainingdata, _remainingSize);
                memcpy(_packetBuffer + _remainingSize, _inputBuffer, (_packetSize - _remainingSize));
                
                NSInteger newSize = (NSInteger)(_packetSize - _remainingSize);
                if (newSize >= 0 && newSize < _inputSize) {
                    _inputBuffer += newSize;
                    _inputSize -= newSize;
                }
                
                //读取存量数据完成，释放
                _remainingSize = 0;
                
                [_remainingData resetBytesInRange:NSMakeRange(0, _remainingData.length)];
                [_remainingData setLength:0];
                
                //处理完整一帧
                [self _startDecodingNALUPacket];
            }
            pStart++;
        }
    }
    
    // 暂存后面残留的数据，下次输入再拼接
    if (_inputSize >= 0) {
        _remainingSize += _inputSize;
        [_remainingData appendBytes:_inputBuffer length:_inputSize];
    }
}

#pragma mark - decode
- (void)_resetDecompressionSession {
    if (decompressionSession) {
//        VTDecompressionSessionInvalidate(decompressionSession);
//        CFRelease(decompressionSession);
//        decompressionSession = NULL;
        return;
    }
    
    const uint8_t* const parameterSetPointers[2] = { _sps, _pps };
    const size_t parameterSetSizes[2] = { _spsSize, _ppsSize };
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    
    if(status == noErr) {
        CFDictionaryRef attrs = NULL;
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
        //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
        
        /**
         *  yuv420 for OpenGL ES，RGB for test image
         **/
//        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        uint32_t v = kCVPixelFormatType_24RGB;          //only for test UIImage， not recommended
        
        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = decompressionSessionDecodeFrameCallback;
        callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
        
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decoderFormatDescription,
                                              NULL,
                                              attrs,
                                              &callBackRecord,
                                              &decompressionSession);
        CFRelease(attrs);
    } else {
        NSLog(@"reset decoder session failed status=%d", (int)status);
    }
}

/**
 decoding NALU frame
 */
- (void)_decodeNALUFrame {
    
    CVPixelBufferRef outputPixelBuffer = NULL;
    if (decompressionSession) {
        // compress bitstream to CMBlockBufferRef
        CMBlockBufferRef blockBuffer = NULL;
        OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                             (void *)_packetBuffer,
                                                             _packetSize,
                                                             kCFAllocatorNull,
                                                             NULL,
                                                             0,
                                                             _packetSize,
                                                             0,
                                                             &blockBuffer);
        
        if (status == kCMBlockBufferNoErr) {
            //CMBlockBufferRef to CMSampleBufferRef
            CMSampleBufferRef sampleBuffer = NULL;
            const size_t sampleSizeArray[] = { _packetSize };
            
//            status = CMSampleBufferCreate(kCFAllocatorDefault,
//                                          blockBuffer,
//                                          true,
//                                          NULL,
//                                          NULL,
//                                          _decoderFormatDescription,
//                                          1, 0, NULL, 1,
//                                          sampleSizeArray,
//                                          &sampleBuffer);
            
            status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                               blockBuffer,
                                               _decoderFormatDescription,
                                               1,
                                               0,
                                               NULL,
                                               1,
                                               sampleSizeArray,
                                               &sampleBuffer);
            
            if (status == kCMBlockBufferNoErr && sampleBuffer) {
                
                VTDecodeFrameFlags flags = 0;
                VTDecodeInfoFlags flagOut = 0;
                OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(decompressionSession,
                                                                          sampleBuffer,
                                                                          flags,
                                                                          &outputPixelBuffer,
                                                                          &flagOut);
                
                if(decodeStatus == kVTInvalidSessionErr) {
                    NSLog(@"Invalid session, reset decoder session");
                } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                    NSLog(@"decode failed status=%d(Bad data)", decodeStatus);
                } else if(decodeStatus != noErr) {
                    NSLog(@"decode failed status=%d", decodeStatus);
                }
                
                CFRelease(sampleBuffer);
            }
        }
        
        if (blockBuffer) {
            CFRelease(blockBuffer);
        }
    }
    
    if (outputPixelBuffer && [_delegate respondsToSelector:@selector(videoDecoder:pixelBuffer:)]) {
        [_delegate videoDecoder:self pixelBuffer:outputPixelBuffer];
    }
}

/**
 处理完原始buffer后，该函数 开始处理完整的NALU帧
 */
- (void)_startDecodingNALUPacket {
    if (!_packetBuffer || _packetSize <= 0) {
        return;
    }
    
    //replace start code with size
    uint32_t naluSize = (uint32_t)(_packetSize - 4);
    uint32_t *pNaluSize = (uint32_t *)_packetBuffer;
    *pNaluSize = CFSwapInt32HostToBig(naluSize);
    
    int naluType = _packetBuffer[4] & 0x1f;
    switch (naluType) {
        // Do not include the 4 byte size. Either in the sps/pps payloads, nor the size values.
        // https://stackoverflow.com/questions/25078364/cmvideoformatdescriptioncreatefromh264parametersets-issues
        case 0x07:
        {
            // sps
            _spsSize = (uint32_t)(_packetSize - 4);
            if (_sps) {
                free(_sps);
                _sps = NULL;
            }
            _sps = malloc(_spsSize);
            memcpy(_sps, _packetBuffer + 4, _spsSize);
        }
            break;
        case 0x08:
        {
            // pps
            _ppsSize = (uint32_t)(_packetSize - 4);
            if (_pps) {
                free(_pps);
                _pps = NULL;
            }
            _pps = malloc(_ppsSize);
            memcpy(_pps, _packetBuffer + 4, _ppsSize);
        }
            break;
        case 0x05:
        {
            // IDR / I frame
            [self _resetDecompressionSession];
            [self _decodeNALUFrame];
        }
            break;
        case 0x01:
        {
            // P frame
            [self _decodeNALUFrame];
        }
            break;
        default:
        {
            // B Frame or other
            [self _decodeNALUFrame];
        }
            break;
    }
}

- (void)endDecoding {
    if (decompressionSession) {
        VTDecompressionSessionInvalidate(decompressionSession);
        CFRelease(decompressionSession);
        decompressionSession = NULL;
    }
}

#pragma mark - Public Methods
- (void)decode:(void *)data_buffer length:(int)length {
    if (_isBackGround) {
        return;
    }
    _inputBuffer = data_buffer;
    _inputSize = length;
    
    [self _splitH264StreamNALU];
}

#pragma mark - decode callback
static void decompressionSessionDecodeFrameCallback(void * decompressionOutputRefCon,
                                                    void * sourceFrameRefCon,
                                                    OSStatus status,
                                                    VTDecodeInfoFlags infoFlags,
                                                    CVImageBufferRef imageBuffer,
                                                    CMTime presentationTimeStamp,
                                                    CMTime presentationDuration ) {
//    NSLog(@"%s, status is %@", __FUNCTION__, (status == noErr) ? @"ok " : @"error");
//    CVPixelBufferLockBaseAddress(imageBuffer, 0);
//    
//    //commit imageBuffer to OpenGL ES
//    NSLog(@"CVImageBufferRef = %@", imageBuffer);
//    
//    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(imageBuffer);
}

@end
