//
//  BigImageLogsController.h
//
//
//  Created by styf on 2021/11/30.
//  Copyright © 2021 styf. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BigImageLogsController : UIViewController
- (instancetype)initWithLogs:(NSArray<NSArray<NSString *> *> *)bigImageLogs;
@end

NS_ASSUME_NONNULL_END
