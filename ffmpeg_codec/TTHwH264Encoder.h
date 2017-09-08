//
//  TTHwH264Encoder.h
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/9/8.
//  Copyright © 2017年 t. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TTVideoEncoding.h"

@interface TTHwH264Encoder : NSObject <TTVideoEncoding>

@property (nonatomic, weak) id<TTVideoEncodingDelegate> delegate;

- (void)encode:(CMSampleBufferRef)sampleBuffer;

@end
