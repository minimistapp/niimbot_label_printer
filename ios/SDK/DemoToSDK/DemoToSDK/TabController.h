//
//  TabController.h
//  DemoToSDK
//
//  Created by jc on 2023/8/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TabController : UIViewController

@property (weak, nonatomic) IBOutlet UITableView *table;

@property (strong, nonatomic) NSMutableArray *datas;


@end

NS_ASSUME_NONNULL_END
