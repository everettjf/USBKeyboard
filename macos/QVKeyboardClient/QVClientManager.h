//
//  QVClientManager.h
//  QVKeyboardClient
//
//  Created by everettjf on 2018/10/14.
//  Copyright © 2018 everettjf. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class QVClientManager;
@protocol QVClientManagerDelegate <NSObject>

@required
- (void)onClientDeviceInfo:(NSDictionary*)info;
- (void)onClientTextMessage:(NSString*)message;
- (void)onClientConnectionCreated;
- (void)onClientConnectionDestroyed;
- (void)onClientErrorOccurred:(NSString*)error;

@end

@interface QVClientManager : NSObject

@property (nonatomic, weak) id<QVClientManagerDelegate> delegate;

+ (instancetype)sharedManager;

- (void)start;

- (void)sendMessage:(NSString*)message callback:(void(^)(BOOL succeed))callback;
- (void)sendDeleteBackward:(void(^)(BOOL succeed))callback;


@end

NS_ASSUME_NONNULL_END
