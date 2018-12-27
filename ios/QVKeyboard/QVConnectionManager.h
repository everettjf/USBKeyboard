//
//  QVConnManager.h
//  QVKeyboard
//
//  Created by everettjf on 2018/10/11.
//  Copyright © 2018 everettjf. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class QVConnectionManager;
@protocol QVConnectionManagerDelegate <NSObject>

@required
- (void) onConnectionListening;
- (void) onConnectionCreated;
- (void) onConnectionDestroyed;
- (void) onConnectionReceivedTextMessage:(NSString*)message;
- (void) onConnectionReceivedDeleteBackward;
- (void) onConnectionErrorOccurred:(NSString*)error;

@end

@interface QVConnectionManager : NSObject

@property (nonatomic, weak) id<QVConnectionManagerDelegate> delegate;

+ (instancetype) sharedManager;

- (void)start;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
