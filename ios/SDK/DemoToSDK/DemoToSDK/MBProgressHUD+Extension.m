//
//  MBProgressHUD+Extension.m
//  XYFrameWork
//
//  Created by EG on 2018/10/18.
//  Copyright © 2018年 xiaoyao. All rights reserved.
//

#import "MBProgressHUD+Extension.h"

@implementation MBProgressHUD (Extension)

+ (void)showSuccess:(NSString *)success {
    [self showSuccess:success toView: [UIApplication sharedApplication].keyWindow];
}

+ (void)showError:(NSString *)error {
    [self showError:error toView: [UIApplication sharedApplication].keyWindow];
}

+ (void)showError:(NSString *)error toView:(UIView *)view {
    [self show:error icon:@"error.png" view:view];
}

+ (void)showSuccess:(NSString *)success toView:(UIView *)view {
    [self show:success icon:@"success.png" view:view];
}

+ (void)show:(NSString *)text icon:(NSString *)icon view:(UIView *)view {
    if (view == nil) view = [[UIApplication sharedApplication].windows lastObject];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
    hud.label.text = text;
    hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[NSString stringWithFormat:@"MBProgressHUD.bundle/%@", icon]]];
    hud.mode = MBProgressHUDModeCustomView;
    hud.removeFromSuperViewOnHide = YES;
    [hud hideAnimated:YES afterDelay:0.7];
}

+ (void)showToastWithMessage:(NSString *)message {
    [MBProgressHUD hideHUDForView:[UIApplication sharedApplication].keyWindow];
    MBProgressHUD *tip = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];
    tip.mode = MBProgressHUDModeText;
    tip.opaque = 0.4;
    tip.label.text = message;
    tip.label.font = [UIFont systemFontOfSize:15];
    tip.label.textColor = [UIColor whiteColor];
    tip.bezelView.layer.cornerRadius = 5;
  
    [tip showAnimated:YES];
    [tip hideAnimated:YES afterDelay:1.5];
}

+ (void)showToastWithMessageDarkColor:(NSString *)message {
    [MBProgressHUD hideHUDForView:[UIApplication sharedApplication].keyWindow];
    MBProgressHUD *tip = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];
    tip.mode = MBProgressHUDModeText;
    tip.opaque = 0.4;
    tip.label.text = message;
    tip.label.font = [UIFont systemFontOfSize:15];
    tip.label.textColor = [UIColor whiteColor];
    tip.bezelView.color =[UIColor blackColor];
    tip.bezelView.layer.cornerRadius = 5;

    [tip showAnimated:YES];
    [tip hideAnimated:YES afterDelay:1.5];
}

+ (void)showToastWithMuliLinesMessage:(NSString *)message {
    [MBProgressHUD hideHUDForView:[UIApplication sharedApplication].keyWindow];
    MBProgressHUD *tip = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];

    tip.opaque = 0.4;
    tip.bezelView.layer.cornerRadius = 5;
    tip.mode = MBProgressHUDModeText;
    tip.detailsLabel.textColor = [UIColor whiteColor];
    tip.detailsLabel.font = [UIFont systemFontOfSize:15];
    tip.detailsLabel.text = message;

    [tip showAnimated:YES];
    [tip hideAnimated:YES afterDelay:1.5];
}

+ (MBProgressHUD *)showMessage:(NSString *)message toView:(UIView *)view {
    if (view == nil) view = [[UIApplication sharedApplication].windows lastObject];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:view animated:YES];
    hud.label.text = message;
    hud.removeFromSuperViewOnHide = YES;
    return hud;
}

+ (MBProgressHUD *)showMessage:(NSString *)message {
    return [self showMessage:message toView:[UIApplication sharedApplication].keyWindow];
}

+ (void)hideHUD {
    [self hideHUDForView:[[UIApplication sharedApplication].windows lastObject]];
}

+ (void)hideHUDForView:(UIView *)view {
    [self hideHUDForView:view animated:YES];
}

@end
