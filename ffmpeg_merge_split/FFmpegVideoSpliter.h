//
//  FFmpegVideoSplitDemo.h
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/9/30.
//  Copyright © 2017年 t. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FFmpegVideoSpliter : NSObject

- (void)splitVideoWithInFilename:(NSString *)infilepath
                         outpath:(NSString *)outpath
                        splitSec:(uint32_t)seconds;

@end
