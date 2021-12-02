//
//  SDBigImageTracker.h
//   
//
//  Created by styf on 2021/11/11.
//  Copyright © 2021 styf. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SDBigImageType) {
    SDBigImageTypeSDWebImage,
    SDBigImageTypeNamedOrFilePath,
    SDBigImageTypeFromData,
};

typedef void(^BigImageTrackerLogBlock)(SDBigImageType type,NSString *logMsg);

// 上报回调，如果需要上报则设置
extern BigImageTrackerLogBlock bigImageTrackerUploadBlock;

// 警告阈值 默认5M
extern NSInteger kWarningImageSize;
// 是否记录警告信息，用于showLogsController查看，默认YES
extern BOOL recordLogs;

@interface SDBigImageTracker : NSObject

/// 显示当前记录的所有警告信息
+ (void)showLogsController;
@end

NS_ASSUME_NONNULL_END
