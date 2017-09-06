//
//  TTFSwH264Decoder.h
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/9/6.
//  Copyright © 2017年 t. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TTVideoDecoding.h"

@interface TTSwH264Decoder : NSObject

@property (nonatomic, weak) id<TTVideoEncodingDelegate> delegate;

- (void)startDecoding:(void *)data_buffer length:(int)length;

@end
