//
//  MBProgressHUD+Extension.h
//  XYFrameWork
//
//  Created by EG on 2018/10/18.
//  Copyright © 2018年 xiaoyao. All rights reserved.
//

#import "MBProgressHUD.h"

NS_ASSUME_NONNULL_BEGIN

@interface MBProgressHUD (Extension)

+ (void)showSuccess:(NSString *)success;

+ (void)showError:(NSString *)error;

+ (void)showSuccess:(NSString *)success toView:(UIView *)view;

+ (void)showError:(NSString *)error toView:(UIView *)view;

+ (void)showToastWithMessage:(NSString *)message;

+ (void)showToastWithMessageDarkColor:(NSString *)message;

+ (void)showToastWithMuliLinesMessage:(NSString *)message;

+ (void)hideHUDForView:(UIView *)view;

+ (void)hideHUD;

+ (MBProgressHUD *)showMessage:(NSString *)message;

+ (MBProgressHUD *)showMessage:(NSString *)message toView:(UIView *)view;

@end

NS_ASSUME_NONNULL_END
