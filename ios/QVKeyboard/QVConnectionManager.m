//
//  QVConnManager.m
//  QVKeyboard
//
//  Created by everettjf on 2018/10/11.
//  Copyright © 2018 everettjf. All rights reserved.
//

#import "QVConnectionManager.h"
#import <UIKit/UIKit.h>
#import "PTMessage.h"
#import "PTChannel.h"
#import "PTProtocol.h"

@interface QVConnectionManager () <PTChannelDelegate>

@property (nonatomic, weak) PTChannel *serverChannel;
@property (nonatomic, weak) PTChannel *peerChannel;

@end

@implementation QVConnectionManager

+ (instancetype)sharedManager {
    static QVConnectionManager *obj;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[QVConnectionManager alloc] init];
    });
    return obj;
}

- (void)start{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self startInternal];
    });
}
- (void)startInternal {
    // Create a new channel that is listening on our IPv4 port
    PTChannel *channel = [PTChannel channelWithDelegate:self];
    [channel listenOnPort:QVKeyboardProtocolIPv4PortNumber IPv4Address:INADDR_LOOPBACK callback:^(NSError *error) {
        // error code == 48 means Address already in use
        if (error && error.code != 48) {
            [self onError:[NSString stringWithFormat:@"Failed to listen on 127.0.0.1:%d: %@", QVKeyboardProtocolIPv4PortNumber, error]];
        } else {
            if(self.delegate){
                [self.delegate onConnectionListening];
            }
            self.serverChannel = channel;
            
            NSLog(@"Listening on 127.0.0.1:%d", QVKeyboardProtocolIPv4PortNumber);
        }
    }];
}

- (void)stop {
    if (self.serverChannel) {
        [self.serverChannel close];
        self.serverChannel = nil;
    }
}

- (void)onError:(NSString*)error {
    NSLog(@"error : %@", error);
    
    if(self.delegate){
        [self.delegate onConnectionErrorOccurred:error];
    }
}


#pragma mark - PTChannelDelegate

- (void)ioFrameChannel:(PTChannel*)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(PTData*)payload {
    if(!self.peerChannel){
        return;
    }
    NSLog(@"didReceiveFrameOfType: %u, %u, %@", type, tag, payload);

    switch (type) {
        case QVKeyboardFrameTypeTextMessage:{
            QVKeyboardTextFrame *textFrame = (QVKeyboardTextFrame*)payload.data;
            textFrame->length = ntohl(textFrame->length);
            
            NSString *message = [[NSString alloc] initWithBytes:textFrame->utf8text length:textFrame->length encoding:NSUTF8StringEncoding];
            
            if(self.delegate){
                [self.delegate onConnectionReceivedTextMessage:message];
            }
            break;
        }
        case QVKeyboardFrameTypeDeleteBackward:{
            if(self.delegate){
                [self.delegate onConnectionReceivedDeleteBackward];
            }
            break;
        }
        case QVKeyboardFrameTypePing:{
            [self.peerChannel sendFrameOfType:QVKeyboardFrameTypePong tag:tag withPayload:nil callback:nil];
            break;
        }
        default:
            break;
    }
}

- (BOOL)ioFrameChannel:(PTChannel*)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    if (channel != self.peerChannel) {
        // A previous channel that has been canceled but not yet ended. Ignore.
        return NO;
    }
    
    // Frame type checking for receive
    switch (type) {
        case QVKeyboardFrameTypeTextMessage:
        case QVKeyboardFrameTypePing:
        case QVKeyboardFrameTypeDeleteBackward:
            return YES;
        default:
            NSLog(@"Unexpected frame of type %u", type);
            return NO;
    }
}

- (void)ioFrameChannel:(PTChannel*)channel didEndWithError:(NSError*)error {
    if(self.delegate){
        [self.delegate onConnectionDestroyed];
    }
}

- (void)ioFrameChannel:(PTChannel*)channel didAcceptConnection:(PTChannel*)otherChannel fromAddress:(PTAddress*)address {
    // Cancel any other connection. We are FIFO, so the last connection
    // established will cancel any previous connection and "take its place".
    if (self.peerChannel) {
        [self.peerChannel cancel];
    }
    
    // Weak pointer to current connection. Connection objects live by themselves
    // (owned by its parent dispatch queue) until they are closed.
    self.peerChannel = otherChannel;
    self.peerChannel.userInfo = address;
    
    if(self.delegate){
        [self.delegate onConnectionCreated];
    }
    
    // Send some information about ourselves to the other end
    [self sendDeviceInfo];
}


#pragma mark - Communicating

- (void)sendDeviceInfo {
    if (!self.peerChannel) {
        return;
    }
    
    UIDevice *device = [UIDevice currentDevice];
    NSDictionary *info = @{
                           @"name":device.name,
                           @"system_version":device.systemVersion,
                           };
    
    dispatch_data_t payload = [info createReferencingDispatchData];
    [self.peerChannel sendFrameOfType:QVKeyboardFrameTypeDeviceInfo tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
        // Only for internal usage, ignore the result
    }];
}

- (void)sendMessage:(NSString*)message {
    if (!self.peerChannel) {
        [self onError:@"Can not send message — not connected"];
        return;
    }
    
    dispatch_data_t payload = QVKeyboardTextDispatchDataWithString(message);
    [self.peerChannel sendFrameOfType:QVKeyboardFrameTypeTextMessage tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
        if (error) {
            [self onError:[NSString stringWithFormat:@"%@", error]];
            return;
        }
        // succeed send
    }];
}

@end
