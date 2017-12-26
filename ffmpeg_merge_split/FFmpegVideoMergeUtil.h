//
//  FFmpegVideoMergeUtil.h
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/12/26.
//  Copyright © 2017年 t. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FFmpegVideoMergeUtil : NSObject
/**
 合并两个视频
 
 iOS 自带AVComposition，更方便

 @param input_file1 视频1
 @param input_file2 视频2
 @param output_file 合并输出视频
 */
- (void)merge_video:(NSString *)input_file1 input_file2:(NSString *)input_file2 output_file:(NSString *)output_file;


@end
