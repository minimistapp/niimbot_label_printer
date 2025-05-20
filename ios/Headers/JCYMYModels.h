//version 3.2.8 20250315

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@interface JCSModelBase : NSObject

- (NSDictionary *)toDictionary ;

@end

@interface JCSColorSupport : JCSModelBase

/// Whether single-color printing is supported, default is supported by all machines
@property (assign,nonatomic) BOOL normalMode;

/// Whether red and black dual-color printing is supported
@property (assign,nonatomic) BOOL rbMode;

/// Whether grayscale printing is supported
@property (assign,nonatomic) BOOL grayMode;

@property (assign,nonatomic) BOOL grayMode16;

@end


@interface JCSQualitySupport : JCSModelBase

/// Whether high-quality printing is supported
@property (assign,nonatomic) BOOL highQuality;

/// Whether high-speed printing is supported
@property (assign,nonatomic) BOOL highSpeed;


@end


@interface JCHalfCutLevel : JCSModelBase


/// Whether half-cut is supported
@property (assign,nonatomic) BOOL supportHalfCut;

/// Meaningful only when supported, maximum value for half-cut
@property (assign,nonatomic) signed int max;

/// Meaningful only when supported, minimum value for half-cut
@property (assign,nonatomic) signed int min;


@end


@interface OutNetBean : JCSModelBase

/// Server type 1.MQTT
@property (assign,nonatomic) int serverType;

/// Domain name, within 50 bytes, longer will be truncated to the first 50 bytes
@property (copy,nonatomic) NSString *domain;
/// Port
@property (assign,nonatomic) uint16_t port;

/// clientId, within 30 bytes, longer will be truncated to the first 30 bytes
@property (copy,nonatomic) NSString *clientId;

/// Username, within 80 bytes, longer will be truncated to the first 80 bytes
@property (copy,nonatomic) NSString *userName;

/// Password, within 30 bytes, longer will be truncated to the first 30 bytes
@property (copy,nonatomic) NSString *password;

/// Push theme data, within 15 bytes, longer will be truncated to the first 15 bytes
@property (copy,nonatomic) NSString *pushTheme;

/// Subscription theme data, within 15 bytes, longer will be truncated to the first 15 bytes
@property (copy,nonatomic) NSString *subscribeTheme;

@end

NS_ASSUME_NONNULL_END
