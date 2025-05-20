//
//  Cell.m
//  DemoToSDK
//
//  Created by jc on 2023/8/25.
//

#import "Cell.h"

@implementation Cell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}
- (IBAction)btn1Clicked:(id)sender {
    if(self.btn1Block){
        self.btn1Block();
    }
}
- (IBAction)btn2Clicked:(id)sender {
    if(self.btn2Block){
        self.btn2Block();
    }
}

@end
