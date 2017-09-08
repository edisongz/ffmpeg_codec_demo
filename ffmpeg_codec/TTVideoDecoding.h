//
//  TTVideoDecoding.h
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/9/6.
//  Copyright © 2017年 t. All rights reserved.
//

#ifndef TTVideoDecoding_h
#define TTVideoDecoding_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol TTVideoDecoding;

@protocol TTVideoDecodingDelegate <NSObject>

@optional
- (void)videoDecoder:(nullable id<TTVideoDecoding>)decoder pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer;

@end

#pragma mark - 抽象接口
@protocol TTVideoDecoding <NSObject>

- (void)setDelegate:(nullable id<TTVideoDecodingDelegate>)delegate;
- (void)decode:(nullable void *)data_buffer length:(int)length;

@end


#endif /* TTVideoDecoding_h */
