//
//  Cell.h
//  DemoToSDK
//
//  Created by jc on 2023/8/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^clickBlock) (void) ;

@interface Cell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIButton *btn1;

@property (weak, nonatomic) IBOutlet UIButton *btn2;
@property (weak, nonatomic) IBOutlet UILabel *lab;

@property (copy, nonatomic)clickBlock btn1Block;
@property (copy, nonatomic)clickBlock btn2Block;

@end

NS_ASSUME_NONNULL_END
