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

@protocol TTVideoEncodingDelegate <NSObject>
@required
- (void)videoDecoder:(nullable id)decoder videoFrame:(nullable id)frame;

@optional
- (void)videoDecoder:(nullable id)decoder pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer;

@end


#endif /* TTVideoDecoding_h */
