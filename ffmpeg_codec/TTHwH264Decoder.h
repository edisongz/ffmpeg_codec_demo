//
//  H264StreamDecoder.h
//  testdemo
//
//  Created by jiang on 2017/6/21.
//  Copyright © 2017年 jiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TTVideoDecoding.h"

@interface TTHwH264Decoder : NSObject <TTVideoDecoding>

@property (nonatomic, weak) id<TTVideoDecodingDelegate> delegate;

/**
 decode received buffer

 @param data_buffer h.264 data buffer
 @param length data buffer size
 */
- (void)decode:(void *)data_buffer length:(int)length;

@end
