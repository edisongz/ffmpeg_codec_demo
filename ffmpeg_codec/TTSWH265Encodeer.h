//
//  TTSWH265Encodeer.h
//  ffmpeg_codec_demo
//
//  Created by 蒋益杰 on 2017/11/4.
//  Copyright © 2017年 t. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TTVideoEncoding.h"

@interface TTSWH265Encodeer : NSObject <TTVideoEncoding>

@property (nonatomic, weak) id<TTVideoEncodingDelegate> delegate;

- (void)encode:(CMSampleBufferRef)sampleBuffer;

@end
