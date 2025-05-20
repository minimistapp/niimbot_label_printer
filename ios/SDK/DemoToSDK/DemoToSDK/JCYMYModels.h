//
//  JCYMYModels.h
//  JCAPI
//
//  Created by yu on 2023/12/13.
//  Copyright © 2023 jc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface JCSModelBase : NSObject

- (NSDictionary *)toDictionary ;

@end

@interface JCSColorSupport : JCSModelBase

/// 是否支持单色打印，默认所有机器都支持
@property (assign,nonatomic) BOOL normalMode;

/// 是否支持红黑双色打印
@property (assign,nonatomic) BOOL rbMode;

/// 是否支持灰阶打印
@property (assign,nonatomic) BOOL grayMode;

@end


@interface JCSQualitySupport : JCSModelBase

/// 是否支持高质量打印
@property (assign,nonatomic) BOOL highQuality;

/// 是否支持高速度打印
@property (assign,nonatomic) BOOL highSpeed;


@end


@interface JCHalfCutLevel : JCSModelBase


/// 是否支持半切
@property (assign,nonatomic) BOOL supportHalfCut;

/// 支持的情况下才有意义，半切最大值
@property (assign,nonatomic) signed int max;

/// 支持的情况下才有意义，半切最小值
@property (assign,nonatomic) signed int min;


@end

NS_ASSUME_NONNULL_END
