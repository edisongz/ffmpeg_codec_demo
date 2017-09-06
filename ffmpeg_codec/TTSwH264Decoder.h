//
//  TTFSwH264Decoder.h
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/9/6.
//  Copyright © 2017年 t. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TTVideoDecoding.h"

@interface TTSwH264Decoder : NSObject <TTVideoDecoding>

@property (nonatomic, weak) id<TTVideoDecodingDelegate> delegate;

- (void)decode:(void *)data_buffer length:(int)length;

@end
