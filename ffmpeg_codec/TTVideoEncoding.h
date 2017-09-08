//
//  TTVideoEncoding.h
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/9/8.
//  Copyright © 2017年 t. All rights reserved.
//

#ifndef TTVideoEncoding_h
#define TTVideoEncoding_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

@protocol TTVideoEncoding;

@protocol TTVideoEncodingDelegate <NSObject>

@optional
- (void)videoEncoder:(nullable id<TTVideoEncoding>)decoder encodedData:(nullable NSData *)encodedData;

@end

#pragma mark - 抽象接口
@protocol TTVideoEncoding <NSObject>

- (void)setDelegate:(nullable id<TTVideoEncodingDelegate>)delegate;
- (void)encode:(nullable CMSampleBufferRef)sampleBuffer;

@end

#endif /* TTVideoEncoding_h */
