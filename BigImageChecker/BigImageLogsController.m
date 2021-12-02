//
//  BigImageLogsController.m
//   
//
//  Created by styf on 2021/11/30.
//  Copyright © 2021 styf. All rights reserved.
//

#import "BigImageLogsController.h"

@interface BigImageLogDetailController : UIViewController
/// 文本框
@property (nonatomic, strong) UITextView *textView;
@end

@implementation BigImageLogDetailController
- (instancetype)initWithLog:(NSString *)log {
    self = [super init];
    if (self) {
        self.view.backgroundColor = UIColor.whiteColor;
        _textView = [[UITextView alloc]initWithFrame:[UIScreen mainScreen].bounds];
        _textView.text = log;
        [self.view addSubview:_textView];
    }
    return self;
}
@end

@interface BigImageLogsController ()<UITableViewDelegate,UITableViewDataSource>
/// 列表
@property (nonatomic, strong) UITableView *tableView;
/// 数据
@property (nonatomic, strong) NSArray<NSArray<NSString *> *> *bigImageLogs;
@end

@implementation BigImageLogsController

- (instancetype)initWithLogs:(NSArray<NSArray<NSString *> *> *)bigImageLogs {
    self = [super init];
    if (self) {
        NSArray<NSArray<NSString *> *> *dataArray = [bigImageLogs copy];
        _bigImageLogs = [dataArray sortedArrayUsingComparator:^NSComparisonResult(NSArray<NSString *> *  _Nonnull obj1, NSArray<NSString *> *  _Nonnull obj2) {
            return [obj1[0] doubleValue] < [obj2[0] doubleValue];
        }];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        //设置导航条背景色
        appearance.backgroundColor = UIColor.whiteColor;
        //设置导航条标题颜色
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes setValue:UIColor.blackColor forKey:NSForegroundColorAttributeName];
        appearance.titleTextAttributes = attributes;
     
        [UINavigationBar appearance].standardAppearance = appearance;
        [UINavigationBar appearance].scrollEdgeAppearance = appearance;
    }
    self.view.backgroundColor = UIColor.whiteColor;
    CGFloat top = 20;
    if (@available(iOS 11.0, *)) {
        top = [UIApplication sharedApplication].keyWindow.safeAreaInsets.top;
    } else {}
    top += 44;
        _tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height - top) style:UITableViewStylePlain];
    [_tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    if (@available(iOS 15.0, *)) {
        _tableView.sectionHeaderTopPadding = 0;
    }
    [self.view addSubview:_tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _bigImageLogs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = _bigImageLogs[indexPath.row][1];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    BigImageLogDetailController *vc = [[BigImageLogDetailController alloc]initWithLog:_bigImageLogs[indexPath.row][2]];
    [self.navigationController pushViewController:vc animated:YES];
}

@end


