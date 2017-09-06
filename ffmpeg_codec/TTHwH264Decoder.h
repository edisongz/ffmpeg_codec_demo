//
//  H264StreamDecoder.h
//  testdemo
//
//  Created by jiang on 2017/6/21.
//  Copyright © 2017年 jiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TTVideoDecoding.h"

@interface TTHwH264Decoder : NSObject

@property (nonatomic, weak) id<TTVideoEncodingDelegate> delegate;

/**
 decode received buffer

 @param inputBuffer h.264 data buffer
 @param inputSize data buffer size
 */
- (void)decode:(uint8_t *)inputBuffer inputSize:(NSInteger)inputSize;

@end
