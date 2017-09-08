//
//  TTx264VideoEncoder.h
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/9/8.
//  Copyright © 2017年 t. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TTVideoEncoding.h"

@interface TTx264VideoEncoder : NSObject <TTVideoEncoding>

@property (nonatomic, weak) id<TTVideoEncodingDelegate> delegate;

- (void)encode:(CMSampleBufferRef)sampleBuffer;

@end
