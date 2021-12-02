//
//  SDBigImageTracker.m
//   
//
//  Created by styf on 2021/11/11.
//  Copyright © 2021 styf. All rights reserved.
//

#import "SDBigImageTracker.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "execinfo.h"
#import <dlfcn.h>
#import "BigImageLogsController.h"

@interface UIView (SDBigImageTracker)
- (void)my_sd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(id)setImageBlock transition:(id)transition cacheType:(NSInteger)cacheType imageURL:(NSURL *)imageURL;
@end

@interface UIImage (SDBigImageTracker)
+ (nullable UIImage *)my_imageNamed:(NSString *)name;
+ (nullable UIImage *)my_imageNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle withConfiguration:(nullable UIImageConfiguration *)configuration API_AVAILABLE(ios(13.0));
+ (nullable UIImage *)my_imageNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle compatibleWithTraitCollection:(nullable UITraitCollection *)traitCollection;
+ (nullable UIImage *)my_imageWithContentsOfFile:(NSString *)path;
+ (nullable UIImage *)my_imageWithData:(NSData *)data;
+ (nullable UIImage *)my_imageWithData:(NSData *)data scale:(CGFloat)scale;
@end

const NSInteger kOneMB = 1024 * 1024;

// 警告阈值 默认5M
NSInteger kWarningImageSize = kOneMB * 5;

// 上报回调，如果需要上报则设置
BigImageTrackerLogBlock bigImageTrackerUploadBlock;

// 是否记录警告信息，用于showLogsController查看，默认YES
BOOL recordLogs = YES;

// 本地图片检查间隔 1秒检查一次
const NSInteger kTimerTimeInterval = 1;
// 存放图片地址或图片名称 防止频繁打印
static NSMutableSet *bigImageSet;
// 所有警告日志
static NSMutableArray<NSArray<NSString *> *> *bigImageLogs;
static dispatch_semaphore_t bigImageLogsLock;

@implementation SDBigImageTracker

+ (void)exchangeSD_setImageMethod {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    Method originalMethod = class_getInstanceMethod(UIView.class, @selector(sd_setImage:imageData:basedOnClassOrViaCustomSetImageBlock:transition:cacheType:imageURL:));
#pragma clang diagnostic pop
    if (originalMethod != NULL) {
        Method swizzledMethod = class_getInstanceMethod(UIView.class, @selector(my_sd_setImage:imageData:basedOnClassOrViaCustomSetImageBlock:transition:cacheType:imageURL:));
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

+ (void)exchangeImageMethod {
    Method originalMethod1 = class_getClassMethod(UIImage.class, @selector(imageNamed:));
    Method swizzledMethod1 = class_getClassMethod(UIImage.class, @selector(my_imageNamed:));
    method_exchangeImplementations(originalMethod1, swizzledMethod1);
    
    Method originalMethod2 = class_getClassMethod(UIImage.class, @selector(imageNamed:inBundle:compatibleWithTraitCollection:));
    if (originalMethod2 != NULL) {
        Method swizzledMethod2 = class_getClassMethod(UIImage.class, @selector(my_imageNamed:inBundle:compatibleWithTraitCollection:));
        method_exchangeImplementations(originalMethod2, swizzledMethod2);
    }
    
    Method originalMethod3 = class_getClassMethod(UIImage.class, @selector(imageWithContentsOfFile:));
    Method swizzledMethod3 = class_getClassMethod(UIImage.class, @selector(my_imageWithContentsOfFile:));
    method_exchangeImplementations(originalMethod3, swizzledMethod3);
    
    Method originalMethod4 = class_getClassMethod(UIImage.class, @selector(imageNamed:inBundle:withConfiguration:));
    if (originalMethod4 != NULL) {
        Method swizzledMethod4 = class_getClassMethod(UIImage.class, @selector(my_imageNamed:inBundle:withConfiguration:));
        method_exchangeImplementations(originalMethod4, swizzledMethod4);
    }
    
    Method originalMethod5 = class_getClassMethod(UIImage.class, @selector(imageWithData:));
    Method swizzledMethod5 = class_getClassMethod(UIImage.class, @selector(my_imageWithData:));
    method_exchangeImplementations(originalMethod5, swizzledMethod5);
    
    Method originalMethod6 = class_getClassMethod(UIImage.class, @selector(imageWithData:scale:));
    Method swizzledMethod6 = class_getClassMethod(UIImage.class, @selector(my_imageWithData:scale:));
    method_exchangeImplementations(originalMethod6, swizzledMethod6);
}

/// 检查本地图片大小
/// @param image 图片
+ (void)checkLocalImage:(UIImage *)image name:(NSString *)name {
    if (image && name.length) {
        static NSMutableDictionary<NSString *,UIImage *> *nameToImageDic;
        static dispatch_once_t onceToken;
        void(^checkBlock)(id) = ^(id timer){
            if (nameToImageDic.count) {
                NSMutableArray<NSString *> *keysToRemove = [NSMutableArray array];
                [nameToImageDic enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, UIImage * _Nonnull obj, BOOL * _Nonnull stop) {
                    CGImageRef cgimage = obj.CGImage;
                    if (cgimage != NULL) {
                        [keysToRemove addObject:key];
                        CGFloat bytes = [self imageSizeWithCGImage:cgimage];
                        if (bytes > kWarningImageSize && ![bigImageSet containsObject:key]) {
                            [bigImageSet addObject:key];
                            CGFloat imageMB = bytes/kOneMB;
                            NSString *warningMsg = [NSString stringWithFormat:@"⚠️⚠️⚠️ 这张本地图片该优化了：[%@] [%.1fM]",key,imageMB];
                            [self recordMsg:warningMsg withKey:[NSString stringWithFormat:@"[%.1fM] [%@]",imageMB,key] size:imageMB];
                            if (bigImageTrackerUploadBlock) {
                                bigImageTrackerUploadBlock(SDBigImageTypeNamedOrFilePath,warningMsg);
                            }
                            NSLog(@"%@",warningMsg);
                        }
                    }
                }];
                
                [nameToImageDic removeObjectsForKeys:keysToRemove];
            }
        };
        
        dispatch_once(&onceToken, ^{
            nameToImageDic = [NSMutableDictionary dictionary];
            if (@available(iOS 10.0, *)) {
                [NSTimer scheduledTimerWithTimeInterval:kTimerTimeInterval repeats:YES block:checkBlock];
            } else {
                // Fallback on earlier versions
            }
        });
        nameToImageDic[name] = image;
    }
}

/// 检查SDWebimage网络图片的大小
/// @param view 发起请求的视图
/// @param url 图片链接
/// @param image 图片
/// @param imageData 图片
+ (void)checkNetworkImageWithView:(UIView *)view url:(NSURL *)url image:(UIImage *)image imageData:(NSData *)imageData {
    if (image && url) {
        CGImageRef cgimage = image.CGImage;
        if (cgimage != NULL) {
            CGFloat bytes = [self imageSizeWithCGImage:cgimage];
            if (bytes > kWarningImageSize && ![bigImageSet containsObject:url.absoluteString]) {
                [bigImageSet addObject:url.absoluteString];
                CGFloat imageMB = bytes/kOneMB;
                NSString *warningMsg = [NSString stringWithFormat:@"⚠️⚠️⚠️ 这张网络图片该优化了：[%@]  [%@]  [%.1fM]",[self viewChain:view],url,imageMB];
                [self recordMsg:warningMsg withKey:[NSString stringWithFormat:@"[%.1fM] [%@]",imageMB,url] size:imageMB];
                if (bigImageTrackerUploadBlock) {
                    bigImageTrackerUploadBlock(SDBigImageTypeSDWebImage,warningMsg);
                }
                NSLog(@"%@",warningMsg);
            }
        }
    }
}

/// 检查从NSData创建的图片大小
/// @param image 图片
+ (void)checkImageData:(UIImage *)image {
    if (image) {
        CGImageRef cgimage = image.CGImage;
        if (cgimage != NULL) {
            CGFloat bytes = [self imageSizeWithCGImage:cgimage];
            CGFloat imageMB = bytes/kOneMB;
            if (bytes > kWarningImageSize) {
                int stack_depth = 20;
                vm_address_t *stack[stack_depth];
                size_t depth = backtrace((void**)stack, stack_depth);
                if (depth > 2) {
                    NSMutableString *warningMsg = [[NSMutableString alloc]initWithFormat:@"⚠️⚠️⚠️ 这张NSData图片该优化了：[%.1fM] 堆栈信息如下:\n",imageMB];
                    for (int i = 2; i < depth; i++) {
                        vm_address_t *addr = stack[i];
                        Dl_info info;
                        dladdr(addr, &info);
                        if (strstr(info.dli_sname, "redacted") == NULL) {
                            char *fname = strrchr(info.dli_fname, '/');
                            if (fname != NULL) {
                                fname += 1;
                            }
                            [warningMsg appendFormat:@"%d：%s   %s  %p  %p\n",i,info.dli_sname,fname == NULL ? info.dli_fname : fname,info.dli_saddr,info.dli_fbase];
                        }
                    }
                    [self recordMsg:warningMsg withKey:[NSString stringWithFormat:@"[%.1fM] NSData",imageMB] size:imageMB];
                    if (bigImageTrackerUploadBlock) {
                        bigImageTrackerUploadBlock(SDBigImageTypeFromData,warningMsg);
                    }
                    NSLog(@"%@",warningMsg);
                }
            }
        }
    }
}

/// 图片解码后大小
/// @param cgimage 图片
+ (CGFloat)imageSizeWithCGImage:(CGImageRef)cgimage {
    size_t width = CGImageGetWidth(cgimage);
    size_t height = CGImageGetHeight(cgimage);
    size_t bytesPerPixel = CGImageGetBitsPerPixel(cgimage) / 8;
    CGFloat size = 1.0 * width * height * bytesPerPixel;
    return size;
}

/// 记录警告信息
/// @param msg 日志
+ (void)recordMsg:(NSString *)msg withKey:(NSString *)key size:(CGFloat)size {
    if (!recordLogs) {
        return;
    }
    dispatch_semaphore_wait(bigImageLogsLock, DISPATCH_TIME_FOREVER);
    [bigImageLogs addObject:@[[NSString stringWithFormat:@"%.1f",size],key,msg]];
    dispatch_semaphore_signal(bigImageLogsLock);
}

//有两点要注意
//1.大图的缩放不要用UIGraphicsBeginImageContextWithOptions或者CGBitmapContextCreate，因为当图片很大的时候，这个函数很有可能创建几百M甚至上G的内存，应该用更底层的ImageIO相关的API
//2.假如ImageView的尺寸是100*100，那么为了不影响用户体验，你应该缩放到100*UIScreem.main.scale
+ (UIImage *)scaledImageFrom:(NSURL *)imageUrl width:(CGFloat)width {
    CGImageSourceRef source =  CGImageSourceCreateWithURL((__bridge CFURLRef)imageUrl, nil);
    CFDictionaryRef options = (__bridge CFDictionaryRef) @{
                                                           (id) kCGImageSourceCreateThumbnailWithTransform : @YES,
                                                           (id) kCGImageSourceCreateThumbnailFromImageAlways : @YES,
                                                           (id) kCGImageSourceThumbnailMaxPixelSize : @(width)
                                                           };
    
    CGImageRef scaledImageRef = CGImageSourceCreateThumbnailAtIndex(source, 0, options);
    UIImage *scaled = [UIImage imageWithCGImage:scaledImageRef];
    CGImageRelease(scaledImageRef);
    return scaled;
}


+ (NSString *)viewChain:(UIView *)view {
    NSMutableArray *array = [NSMutableArray array];
    
    do {
        [array addObject:NSStringFromClass(view.class)];
        view = view.superview;
    } while (view && array.count < 7);
    return [array componentsJoinedByString:@"-"];
}

/// 显示当前记录的所有警告信息
+ (void)showLogsController {
    BigImageLogsController *vc = [[BigImageLogsController alloc]initWithLogs:bigImageLogs];
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    if ([rootVC isKindOfClass:UITabBarController.class]) {
        rootVC = ((UITabBarController *)rootVC).selectedViewController;
    }
    if ([rootVC isKindOfClass:UINavigationController.class]) {
        [((UINavigationController *)rootVC)pushViewController:vc animated:YES];
    }
}

@end

@implementation UIView (SDBigImageTracker)

#ifdef DEBUG
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bigImageSet = [NSMutableSet set];
        bigImageLogs = [NSMutableArray array];
        bigImageLogsLock = dispatch_semaphore_create(1);
        [SDBigImageTracker exchangeSD_setImageMethod];
        [SDBigImageTracker exchangeImageMethod];
    });
}
#endif

- (void)my_sd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(id)setImageBlock transition:(id)transition cacheType:(NSInteger)cacheType imageURL:(NSURL *)imageURL {
    [SDBigImageTracker checkNetworkImageWithView:self url:imageURL image:image imageData:imageData];
    [self my_sd_setImage:image imageData:imageData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:transition cacheType:cacheType imageURL:imageURL];
}

@end

@implementation UIImage (SDBigImageTracker)

+ (nullable UIImage *)my_imageNamed:(NSString *)name {
    UIImage *image = [self my_imageNamed:name];
    [SDBigImageTracker checkLocalImage:image name:name];
    return image;
}

+ (nullable UIImage *)my_imageNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle withConfiguration:(nullable UIImageConfiguration *)configuration {
    UIImage *image = [self my_imageNamed:name inBundle:bundle withConfiguration:configuration];
    [SDBigImageTracker checkLocalImage:image name:name];
    return image;
}

+ (nullable UIImage *)my_imageNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle compatibleWithTraitCollection:(nullable UITraitCollection *)traitCollection {
    UIImage *image = [self my_imageNamed:name inBundle:bundle compatibleWithTraitCollection:traitCollection];
    [SDBigImageTracker checkLocalImage:image name:name];
    return image;
}

+ (nullable UIImage *)my_imageWithContentsOfFile:(NSString *)path {
    UIImage *image = [self my_imageWithContentsOfFile:path];
    [SDBigImageTracker checkLocalImage:image name:path];
    return image;
}

+ (nullable UIImage *)my_imageWithData:(NSData *)data {
    UIImage *image = [self my_imageWithData:data];
    [SDBigImageTracker checkImageData:image];
    return image;
}

+ (nullable UIImage *)my_imageWithData:(NSData *)data scale:(CGFloat)scale {
    UIImage *image = [self my_imageWithData:data scale:scale];
    [SDBigImageTracker checkImageData:image];
    return image;
}
@end
