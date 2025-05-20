//
//  Model.h
//  DemoToSDK
//
//  Created by jc on 2023/8/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Model : NSObject


@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSString *ip;
@property (copy, nonatomic) NSString *port;
@property (assign, nonatomic) BOOL connected;

@end

NS_ASSUME_NONNULL_END
