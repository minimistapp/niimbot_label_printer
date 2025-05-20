//
//  TabController.m
//  DemoToSDK
//
//  Created by jc on 2023/8/25.
//

#import "TabController.h"
#import "Cell.h"
#import "JCAPI.h"
#import "MBProgressHUD+Extension.h"
#import "Model.h"

@interface TabController () <UITableViewDelegate, UITableViewDataSource>

@property(strong, nonatomic) MBProgressHUD *hud;

@end

@implementation TabController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.

  self.table.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self.table reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return self.datas.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  __weak typeof(self) weakSelf = self;
  Cell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"
                                               forIndexPath:indexPath];
  Model *m = [self.datas objectAtIndex:indexPath.row];
  cell.lab.text = m.name;
  if (m.connected) {
    cell.btn1.hidden = m.ip != nil;
  } else {
    cell.btn1.hidden = YES;
  }
  [cell.btn2 setTitle:m.connected ? @"Disconnect" : @"Connect"
             forState:UIControlStateNormal];
  [cell.btn2 setTitleColor:m.connected ? UIColor.redColor : UIColor.greenColor
                  forState:UIControlStateNormal];
  cell.btn2Block = ^{
    if (m.connected) {
      [JCAPI closePrinter];
    } else {
      weakSelf.hud = [MBProgressHUD showMessage:@"Connecting..."];
      weakSelf.hud.backgroundColor = [[UIColor alloc] initWithRed:0
                                                            green:0
                                                             blue:0
                                                            alpha:0.4];
      if (m.ip) {
        [JCAPI openPrinterHost:m.ip
                    completion:^(BOOL isSuccess) {
                      m.connected = isSuccess;
                      [tableView reloadData];
                      if (isSuccess) {
                        [weakSelf.hud hideAnimated:NO];
                        weakSelf.hud = [MBProgressHUD
                            showMessage:@"Connection successful..."];
                        [weakSelf.hud hideAnimated:YES afterDelay:1.f];
                      }
                    }];
      } else {
        [JCAPI openPrinter:m.name
                completion:^(BOOL isSuccess) {
                  m.connected = isSuccess;
                  [tableView reloadData];
                  if (isSuccess) {
                    [weakSelf.hud hideAnimated:NO];
                    weakSelf.hud =
                        [MBProgressHUD showMessage:@"Connection successful..."];
                    [weakSelf.hud hideAnimated:YES afterDelay:1.f];
                  }
                }];
      }
    }
  };
  cell.btn1Block = ^{
    if (m.connected) {
      UIAlertController *alter = [UIAlertController
          alertControllerWithTitle:@"Network Configuration"
                           message:@"Network configuration takes about 10-20s, "
                                   @"please wait patiently"
                    preferredStyle:UIAlertControllerStyleAlert];
      [alter addTextFieldWithConfigurationHandler:^(
                 UITextField *_Nonnull textField) {
        textField.placeholder = @"Please enter Wi-Fi name";
        textField.tag = 100;
      }];
      [alter addTextFieldWithConfigurationHandler:^(
                 UITextField *_Nonnull textField) {
        textField.placeholder = @"Please enter Wi-Fi password";
        textField.tag = 101;
      }];
      UIAlertAction *action = [UIAlertAction
          actionWithTitle:@"Start Network Configuration"
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *_Nonnull action) {
                    if (alter.textFields && alter.textFields.count >= 2) {
                      NSString *name;
                      NSString *pwd;
                      for (UITextField *textF in alter.textFields) {
                        if (textF.tag == 100) {
                          name = textF.text;
                        }
                        if (textF.tag == 101) {
                          pwd = textF.text;
                        }
                      }
                      weakSelf.hud =
                          [MBProgressHUD showMessage:@"Configuring network..."];
                      [JCAPI
                          configurationWifi:name
                                   password:pwd
                                 completion:^(NSDictionary *printDicInfo) {
                                   NSString *str = @"";
                                   if ([@"0" isEqualToString:
                                                 printDicInfo[@"statusCode"]]) {
                                     NSLog(@"Network configuration successful");
                                     str = @"Network configuration successful";
                                   } else if ([@"-1" isEqualToString:
                                                         printDicInfo
                                                             [@"statusCode"]]) {
                                     NSLog(@"Network configuration failed");
                                     str = @"Network configuration failed";
                                   } else if ([@"-2" isEqualToString:
                                                         printDicInfo
                                                             [@"statusCode"]]) {
                                     NSLog(@"Printer busy");
                                     str = @"Printer busy";
                                   } else if ([@"-3" isEqualToString:
                                                         printDicInfo
                                                             [@"statusCode"]]) {
                                     NSLog(@"Network configuration not "
                                           @"supported");
                                     str =
                                         @"Network configuration not supported";
                                   }
                                   [weakSelf.hud hideAnimated:NO];
                                   weakSelf.hud =
                                       [MBProgressHUD showMessage:str];
                                   [weakSelf.hud hideAnimated:YES
                                                   afterDelay:2.f];
                                 }];
                    }
                  }];
      UIAlertAction *action1 =
          [UIAlertAction actionWithTitle:@"Cancel"
                                   style:UIAlertActionStyleCancel
                                 handler:^(UIAlertAction *_Nonnull action){

                                 }];
      [alter addAction:action];
      [alter addAction:action1];
      [weakSelf presentViewController:alter animated:YES completion:nil];
    }
  };
  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return 50.f;
}

- (NSMutableArray *)datas {
  if (!_datas) {
    _datas = [NSMutableArray array];
  }
  return _datas;
  ;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self.view removeFromSuperview];
  [self removeFromParentViewController];
}
- (IBAction)closeTab:(id)sender {
  [self.view removeFromSuperview];
  [self removeFromParentViewController];
}

- (void)dealloc {
  NSLog(@"----Deallocated");
}

@end
