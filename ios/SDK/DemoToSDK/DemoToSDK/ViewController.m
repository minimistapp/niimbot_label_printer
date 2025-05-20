//
//  ViewController.m
//  DemoToSDK
//
//  Created by jc on 2023/8/25.
//

#import "ViewController.h"
#import "JCAPI.h"
#import "MBProgressHUD+Extension.h"
#import "Model.h"
#import "TabController.h"

@interface ViewController ()

@property(strong, nonatomic) NSMutableArray *datas;
@property(strong, nonatomic) MBProgressHUD *hud;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  self.view.layer.cornerRadius = 20.f;
}

- (IBAction)btn1Clicked:(id)sender {
  __weak typeof(self) weakSelf = self;
  self.hud = [MBProgressHUD showMessage:@"Searching..."];
  self.hud.backgroundColor = [[UIColor alloc] initWithRed:0
                                                    green:0
                                                     blue:0
                                                    alpha:0.4];
  // Call Bluetooth printer scanning method
  [JCAPI scanBluetoothPrinter:^(NSArray *scanedPrinterNames) {
    // Remove existing data
    [weakSelf.datas removeAllObjects];
    // Iterate through the scanned Bluetooth printer names
    for (NSString *name in scanedPrinterNames) {
      // Check name length, if not within the specified range, skip
      if (name.length < 6 || name.length > 20) {
        continue;
      }
      // Create a Model object and set its properties
      Model *m = [[Model alloc] init];
      m.name = name;
      // Add the Model object to the data array
      [weakSelf.datas addObject:m];
    }
    // Call Wi-Fi printer scanning method
    [JCAPI scanWifiPrinter:^(NSArray *scanedPrinterNames1) {
      // Hide progress indicator (hud)
      [weakSelf.hud hideAnimated:NO];
      UIStoryboard *main = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
      // Instantiate a view controller named "TabController"
      TabController *vc =
          [main instantiateViewControllerWithIdentifier:@"TabController"];
      // Pass data (weakSelf.datas) to the view controller
      vc.datas = weakSelf.datas;
      // Add this view controller as a child view controller of the current view
      // controller
      [weakSelf addChildViewController:vc];
      // Add the view controller's view to the current view
      [weakSelf.view addSubview:vc.view];
    }];
  }];
}
- (IBAction)btn2Clicked:(id)sender {
  [JCAPI closePrinter];
}

- (IBAction)btn3Clicked:(id)sender {

  [self printLabel:1 pageCount:1];
}

- (IBAction)btn4Clicked:(id)sender {
  [self printLabel:1 pageCount:3];
}

- (IBAction)btn5Clicked:(id)sender {
  NSString *fontPath = [NSString
      stringWithFormat:@"%@/font", [NSHomeDirectory()
                                       stringByAppendingString:@"/Documents"]];
  // Font storage path
  NSLog(@"Print settings: Set default font path");
  [JCAPI initImageProcessing:fontPath error:nil];
}

- (void)printLabel:(NSInteger)quantity pageCount:(NSInteger)pageCount {
  __weak typeof(self) weakSelf = self;
  self.hud = [MBProgressHUD showMessage:@"Printing..."];
  self.hud.backgroundColor = [[UIColor alloc] initWithRed:0
                                                    green:0
                                                     blue:0
                                                    alpha:0.4];
  //    NSString *str = [[NSBundle mainBundle] pathForResource:@"ZT001"
  //    ofType:@"ttf"]; NSArray *arr = [str
  //    componentsSeparatedByString:@"/ZT001.ttf"]; [JCAPI
  //    initImageProcessing:arr.firstObject error:nil];

  [JCAPI setPrintWithCache:YES];
  NSInteger totalQuantity = pageCount * quantity;
  NSLog(@"Total quantity to print:%ld", (long)totalQuantity);
  NSLog(@"Test - Set total number of prints");

  [JCAPI setTotalQuantityOfPrints:totalQuantity];
  // Loop drawing complete
  [JCAPI getPrintingErrorInfo:^(NSString *printInfo) {
    if ([printInfo isEqualToString:@"19"]) {

    } else {
      NSLog(@"---------printInfo=%@", printInfo);
      NSString *desc = nil;
      switch (printInfo.integerValue) {
      case 1:
        desc = @"Exception: Cover open! Error code 1";
        break;
      case 2:
        desc = @"Exception: Out of paper! Error code 2";
        break;
      case 3:
        desc = @"Exception: Low battery! Error code 3";
        break;
      case 4:
        desc = @"Exception: Battery abnormal! Error code 4";
        break;
      case 5:
        desc = @"Exception: Manually stopped! Error code 5";
        break;
      case 6:
        desc = @"Exception: Data error! Error code 6";
        break;
      case 7:
        desc = @"Exception: Over temperature! Error code 7";
        break;
      case 8:
        desc = @"Exception: Paper feed abnormal! Error code 8";
        break;
      case 9:
        desc = @"Exception: Printer busy! Error code 9";
        break;
      case 10:
        desc = @"Exception: Print head not detected! Error code 10";
        break;
      case 11:
        desc = @"Exception: Ambient temperature too low Error code 11";
        break;
      case 12:
        desc = @"Exception: Print head not locked! Error code 12";
        break;
      case 13:
        desc = @"Exception: Ribbon not detected! Error code 13";
        break;
      case 14:
        desc = @"Exception: Mismatched ribbon! Error code 14";
        break;
      case 15:
        desc = @"Exception: Ribbon used up! Error code 15";
        break;
      case 16:
        desc = @"Exception: Unsupported paper type! Error code 16";
        break;
      case 17:
        desc = @"Exception: Setting paper failed! Error code 17";
        break;
      case 18:
        desc = @"Exception: Setting print mode failed! Error code 18";
        break;
      case 19:
        desc = @"Exception: Setting print density failed! Error code 19";
        break;
      case 20:
        desc = @"Exception: Writing Rfid failed! Error code 20";
        break;
      case 21:
        desc = @"Exception: Margin setting error! Error code 21";
        break;
      case 22:
        desc = @"Exception: Communication abnormal! Error code 22";
        break;
      case 23:
        desc = @"Exception: Printer disconnected! Error code 23";
        break;
      case 24:
        desc = @"Exception: Drawing board parameter error! Error code 24";
        break;
      case 25:
        desc = @"Exception: Rotation angle parameter error! Error code 25";
        break;
      case 26:
        desc = @"Exception: JSON parameter error! Error code 26";
        break;
      case 27:
        desc = @"Exception: Paper feed abnormal! Error code 27";
        break;
      case 28:
        desc = @"Exception: Paper feed abnormal! Error code 28";
        break;
      case 29:
        desc = @"Exception: RFID label printed in non-RFID mode! Error code 29";
        break;
      case 30:
        desc = @"Exception: Density setting not supported! Error code 30";
        break;
      case 32:
        desc = @"Exception: Material setting failed! Error code 32";
        break;
      case 33:
        desc = @"Exception: Unsupported material! Error code 33";
        break;
      default:
        desc = [NSString
            stringWithFormat:@"Unknown error, error code:%@", printInfo];
        break;
      }
      [weakSelf.hud hideAnimated:NO];
      weakSelf.hud = [MBProgressHUD showMessage:desc];
      [weakSelf.hud hideAnimated:YES afterDelay:1.f];
    }
  }];
  [JCAPI getPrintingCountInfo:^(NSDictionary *dic) {
    NSLog(@"------------获取的页码为:--%@", dic);

    NSString *totalCount = [dic valueForKey:@"totalCount"];
    NSLog(@"Number of copies printed: %@", totalCount);
    NSLog(@"Total number of prints: %ld", (long)totalQuantity);
    if (totalCount.intValue == totalQuantity) {
      [JCAPI endPrint:^(BOOL isSuccess) {
        [weakSelf.hud hideAnimated:NO];
        weakSelf.hud = [MBProgressHUD showMessage:@"Printing complete"];
        [weakSelf.hud hideAnimated:YES afterDelay:1.f];
      }];
    }
  }];
  NSLog(@"Test - Start print job");
  [JCAPI startJob:3
      withPaperStyle:1
      withCompletion:^(BOOL isSuccess) {
        NSLog(@"Test - Start generating print data and submit");
        NSLog(@"pageCount :%ld", (long)pageCount);
        [self generateLabelAndCommit:quantity
                      withTotalPages:pageCount
                    withPrintedPages:0];
      }];
}

- (void)generateLabelAndCommit:(NSInteger)quantity
                withTotalPages:(NSInteger)totalPages
              withPrintedPages:(NSInteger)printedPages {
  NSLog(@"Test - Generate print data");
  [self drawLabel];
  NSLog(@"Test - Submit print data");
  NSLog(@"Total printing pages: %ld", (long)totalPages);
  [self commitLabelGeneration:quantity
               withTotalPages:totalPages
             withPrintedPages:printedPages];
}
- (void)drawLabel {
  //    [JCAPI initDrawingBoard:50 withHeight:30 withHorizontalShift:0
  //    withVerticalShift:0 rotate:0 font:nil];
  [JCAPI initDrawingBoard:50
               withHeight:30
      withHorizontalShift:0
        withVerticalShift:0
                   rotate:0
                fontArray:@[ @"ZT008.ttf", @"ZT025.ttf" ]];
  [JCAPI drawLableText:7.5
                        withY:5.0
                    withWidth:40.5
                   withHeight:6.5
                   withString:@"F金 银花 开植物 饮料 门"
               withFontFamily:@"ZT025"
                 withFontSize:3.5
                   withRotate:0
      withTextAlignHorizonral:0
        withTextAlignVertical:1
                 withLineMode:1
            withLetterSpacing:0
              withLineSpacing:1
                withFontStyle:@[ @0, @0, @0, @0 ]];
  //    [JCAPI drawLableText:7.5 withY:5.0 withWidth:40.5 withHeight:6.5
  //    withString:@"F金 银花 开植物 饮料 门" withFontFamily:@""
  //    withFontSize:3.5 withRotate:0 withTextAlignHorizonral:0
  //    withTextAlignVertical:1 withLineMode:1 withLetterSpacing:0
  //    withLineSpacing:1 withFontStyle:@[@0,@0,@0,@0]];
  [JCAPI drawLableQrCode:3
                   withY:12
               withWidth:10
              withHeight:10
              withString:@"123456"
              withRotate:0
            withCodeType:31];
}

- (void)commitLabelGeneration:(NSInteger)quantity
               withTotalPages:(NSInteger)totalPages
             withPrintedPages:(NSInteger)printedPages {
  NSLog(@"Test - Submit data total pages: %ld", (long)totalPages);
  NSLog(@"Test - Submit data printed pages: %ld", (long)printedPages);

  NSString *data = [JCAPI GenerateLableJson];
  NSLog(@"Print data: %@", data);
  [JCAPI commit:[JCAPI GenerateLableJson]
      withOnePageNumbers:(int)quantity
            withComplete:^(BOOL isSuccess) {
              // 此次还需要判断是否已经提交完成
              if (isSuccess) {
                NSLog(@"Test - Submit data total pages: %ld", (long)totalPages);
                if (totalPages > printedPages + 1) {
                  [self generateLabelAndCommit:quantity
                                withTotalPages:totalPages
                              withPrintedPages:printedPages + 1];
                } else {
                  NSLog(@"Test - Data submitted completed");
                }

              } else {
                NSLog(@"Test - Data submission failed");
              }
            }];
}

- (NSMutableArray *)datas {
  if (!_datas) {
    _datas = [NSMutableArray array];
  }
  return _datas;
  ;
}

@end
