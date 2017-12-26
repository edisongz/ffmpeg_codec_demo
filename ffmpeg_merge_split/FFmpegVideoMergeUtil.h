//
//  FFmpegVideoMergeUtil.h
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/12/26.
//  Copyright © 2017年 t. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^MergeCompletionBlock)(NSString *outputPath);

@interface FFmpegVideoMergeUtil : NSObject

/**
 合并多个视频
 
 iOS 自带AVComposition，更方便

 @param paths 视频存储地址
 @param output_file 输出文件
 @param completion 回调
 */
- (void)merge_videos:(NSArray<NSString *> *)paths output_file:(NSString *)output_file completion:(MergeCompletionBlock)completion;

@end
