//
//  ViewController.m
//  ffmpeg_codec_demo
//
//  Created by jiang on 2017/9/6.
//  Copyright © 2017年 t. All rights reserved.
//

#import "ViewController.h"
#import "TTSwH264Decoder.h"
#import "TTHwH264Decoder.h"
#import "FFmpegVideoSpliter.h"
#import "FFmpegVideoMergeUtil.h"

#import "TTSWH265Encoder.h"

#define FILE_BUF_SIZE       4096

@interface ViewController () <TTVideoDecodingDelegate>
{
    uint8_t *_filebuf;        //读入文件缓存
    dispatch_queue_t _serialQueue;
}

@property (nonatomic, strong) id<TTVideoEncoding> encoder;
@property (nonatomic, strong) id<TTVideoDecoding> decoder;
@property (nonatomic, strong) UIImageView *imageView;

@property (nonatomic, strong) FFmpegVideoSpliter *videoSplitter;
@property (nonatomic, strong) FFmpegVideoMergeUtil *videoMerger;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
//    _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 20, 240, 320)];
//    _imageView.contentMode = UIViewContentModeScaleAspectFit;
//    [self.view addSubview:_imageView];
//
//    // h.264解码测试
//    _serialQueue = dispatch_queue_create("com.video.decodequeue", NULL);
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        self.encoder = [[TTSWH265Encoder alloc] init];
//    });
    
//
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"abc" ofType:@"h264"];
//        FILE *fp = fopen([filePath UTF8String], "rb");
//        if (!fp) {
//            fprintf(stderr, "Could not open file\n");
//            return;
//        }
//        _filebuf = malloc(FILE_BUF_SIZE);
//
//        //hw
////        _decoder = [[TTHwH264Decoder alloc] init];
////        [_decoder setDelegate:self];
//        //sw
//        _decoder = [[TTSwH264Decoder alloc] init];
//        [_decoder setDelegate:self];
//
//        int nDataLen = 0;
//        while (true) {
//            nDataLen = (int)fread(_filebuf, 1, FILE_BUF_SIZE, fp);
//            if (nDataLen <= 0) {
//                fclose(fp);
//                break;
//            } else {
//                [_decoder decode:_filebuf length:nDataLen];
//            }
//        }
//
//        free(_filebuf);
//        fclose(fp);
//    });
    
    //videoSplitter 测试
//    _videoSplitter = [[FFmpegVideoSpliter alloc] init];

    NSString *path = [[NSBundle mainBundle] pathForResource:@"war3end" ofType:@"mp4"];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths objectAtIndex:0];
    NSString *outfilePath = [docDir stringByAppendingFormat:@"/out_file.mp4"];
//    NSLog(@"outpath = %@", outfilePath);
//    [_videoSplitter splitVideoWithInFilename:path outpath:outfilePath splitSec:10];
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weakSelf) sself = weakSelf;
        if (!sself) {
            return ;
        }
        
        NSString *path1 = [[NSBundle mainBundle] pathForResource:@"sintel" ofType:@"mp4"];
        NSString *outfilePath1 = [docDir stringByAppendingFormat:@"/merged_file.mp4"];
        NSLog(@"%@", outfilePath1);
        
        sself.videoMerger = [[FFmpegVideoMergeUtil alloc] init];
        [sself.videoMerger merge_video:path1 input_file2:path1 output_file:outfilePath1];
    });
}

- (void)videoDecoder:(id)decoder pixelBuffer:(CVPixelBufferRef)pixelBuffer {
#warning - 实际使用时，交给GPUImage ，此处仅为测试
    CIImage *ciimage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    UIImage *image = [UIImage imageWithCIImage:ciimage];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = image;
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
