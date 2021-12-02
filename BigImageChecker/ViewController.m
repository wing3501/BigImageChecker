//
//  ViewController.m
//  BigImageChecker
//
//  Created by styf on 2021/12/2.
//

#import "ViewController.h"
#import "SDBigImageTracker.h"
#import "UIImageView+WebCache.h"
@interface ViewController ()
/// <#name#>
@property (nonatomic, strong) UIImageView *imageView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _imageView = [[UIImageView alloc]initWithFrame:[UIScreen mainScreen].bounds];
//    _imageView.image = [UIImage imageNamed:@"img"];
    [self.view addSubview:_imageView];
    [_imageView sd_setImageWithURL:[NSURL URLWithString:@"https://gimg2.baidu.com/image_search/src=http%3A%2F%2Fpic1.win4000.com%2Fwallpaper%2F2018-11-19%2F5bf2563439059.jpg&refer=http%3A%2F%2Fpic1.win4000.com&app=2002&size=f9999,10000&q=a80&n=0&g=0n&fmt=jpeg"]];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [SDBigImageTracker showLogsController];
}
@end
