//
//  QVClientManager.m
//  QVKeyboardClient
//
//  Created by everettjf on 2018/10/14.
//  Copyright © 2018 everettjf. All rights reserved.
//

#import "QVClientManager.h"
#import "PTUSBHub.h"
#import "PTMessage.h"
#import "PTChannel.h"


static const NSTimeInterval PTAppReconnectDelay = 1.0;

@interface QVClientManager ()<PTChannelDelegate>
{
    PTChannel *_connectedChannel;
}
@property (nonatomic,strong) PTChannel *connectedChannel;

@property (nonatomic,assign) BOOL notConnectedQueueSuspended;
@property (nonatomic,strong) NSNumber *connectingToDeviceID;
@property (nonatomic,strong) NSNumber *connectedDeviceID;
@property (nonatomic,strong) NSDictionary *connectedDeviceProperties;
@property (nonatomic,strong) NSDictionary *remoteDeviceInfo;
@property (nonatomic,strong) dispatch_queue_t notConnectedQueue;
@property (nonatomic,strong) NSMutableDictionary *pings;


@end

@implementation QVClientManager

+ (instancetype)sharedManager{
    static QVClientManager *obj;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[QVClientManager alloc] init];
    });
    return obj;
}

- (void)start{
    
    // We use a serial queue that we toggle depending on if we are connected or
    // not. When we are not connected to a peer, the queue is running to handle
    // "connect" tries. When we are connected to a peer, the queue is suspended
    // thus no longer trying to connect.
    self.notConnectedQueue = dispatch_queue_create("QVKeyboard.notConnectedQueue", DISPATCH_QUEUE_SERIAL);
    
    // Start listening for device attached/detached notifications
    [self startListeningForDevices];
    
    // Start pinging
    [self ping];
}

- (PTChannel*)connectedChannel {
    return _connectedChannel;
}

- (void)setConnectedChannel:(PTChannel*)connectedChannel {
    _connectedChannel = connectedChannel;
    
    // Toggle the self.notConnectedQueue depending on if we are connected or not
    if (!self.connectedChannel && self.notConnectedQueueSuspended) {
        dispatch_resume(self.notConnectedQueue);
        self.notConnectedQueueSuspended = NO;
    } else if (self.connectedChannel && !self.notConnectedQueueSuspended) {
        dispatch_suspend(self.notConnectedQueue);
        self.notConnectedQueueSuspended = YES;
    }
    
    if (!self.connectedChannel && self.connectingToDeviceID) {
        [self enqueueConnectToUSBDevice];
    }
}


- (void)sendMessage:(NSString*)message callback:(void(^)(BOOL succeed))callback{
    if (!self.connectedChannel) {
        callback(NO);
        return;
    }
    dispatch_data_t payload = QVKeyboardTextDispatchDataWithString(message);
    [self.connectedChannel sendFrameOfType:QVKeyboardFrameTypeTextMessage tag:PTFrameNoTag withPayload:payload callback:^(NSError *error) {
        if(error){
            callback(NO);
            NSLog(@"Failed to send message: %@", error);
            return;
        }
        callback(YES);
    }];
}

- (void)sendDeleteBackward:(void(^)(BOOL succeed))callback{
    if (!self.connectedChannel) {
        callback(NO);
        return;
    }
    [self.connectedChannel sendFrameOfType:QVKeyboardFrameTypeDeleteBackward tag:PTFrameNoTag withPayload:nil callback:^(NSError *error) {
        if(error){
            callback(NO);
            NSLog(@"Failed to send DeleteBackward: %@", error);
            return;
        }
        callback(YES);
    }];
}


#pragma mark - Ping


- (void)pongWithTag:(uint32_t)tagno error:(NSError*)error {
    NSNumber *tag = [NSNumber numberWithUnsignedInt:tagno];
    NSMutableDictionary *pingInfo = [self.pings objectForKey:tag];
    if (pingInfo) {
        NSDate *now = [NSDate date];
        [pingInfo setObject:now forKey:@"date ended"];
        [self.pings removeObjectForKey:tag];
        NSLog(@"Ping total roundtrip time: %.3f ms", [now timeIntervalSinceDate:[pingInfo objectForKey:@"date created"]]*1000.0);
    }
}


- (void)ping {
    if (!self.connectedChannel) {
        [self performSelector:@selector(ping) withObject:nil afterDelay:1.0];
        return;
    }
    
    if (!self.pings) {
        self.pings = [NSMutableDictionary dictionary];
    }
    
    uint32_t tagno = [self.connectedChannel.protocol newTag];
    NSNumber *tag = [NSNumber numberWithUnsignedInt:tagno];
    NSMutableDictionary *pingInfo = [@{
                                       @"date created" : [NSDate date]
                                       } mutableCopy];
    [self.pings setObject:pingInfo forKey:tag];
    
    [self.connectedChannel sendFrameOfType:QVKeyboardFrameTypePing tag:tagno withPayload:nil callback:^(NSError *error) {
        
        [self performSelector:@selector(ping) withObject:nil afterDelay:1.0];
        
        [pingInfo setObject:[NSDate date] forKey:@"date sent"];
        
        if (error) {
            [self.pings removeObjectForKey:tag];
        }
    }];
}

#pragma mark - PTChannelDelegate


- (BOOL)ioFrameChannel:(PTChannel*)channel shouldAcceptFrameOfType:(uint32_t)type tag:(uint32_t)tag payloadSize:(uint32_t)payloadSize {
    switch (type) {
        case QVKeyboardFrameTypeTextMessage:
        case QVKeyboardFrameTypeDeviceInfo:
        case QVKeyboardFrameTypePong:
        case PTFrameTypeEndOfStream:{
            return YES;
        }
        default:{
            NSLog(@"Unexpected frame of type %u", type);
            [channel close];
            return NO;
        }
    }
}

- (void)ioFrameChannel:(PTChannel*)channel didReceiveFrameOfType:(uint32_t)type tag:(uint32_t)tag payload:(PTData*)payload {
    NSLog(@"received %@, %u, %u, %@", channel, type, tag, payload);
    
    switch (type) {
        case QVKeyboardFrameTypeDeviceInfo:{
            NSDictionary *deviceInfo = [NSDictionary dictionaryWithContentsOfDispatchData:payload.dispatchData];
            if(self.delegate){
                [self.delegate onClientDeviceInfo:deviceInfo];
            }
            break;
        }
        case QVKeyboardFrameTypeTextMessage:{
            QVKeyboardTextFrame *textFrame = (QVKeyboardTextFrame*)payload.data;
            textFrame->length = ntohl(textFrame->length);
            NSString *message = [[NSString alloc] initWithBytes:textFrame->utf8text length:textFrame->length encoding:NSUTF8StringEncoding];
            if(self.delegate){
                [self.delegate onClientTextMessage:message];
            }
            break;
        }
        case QVKeyboardFrameTypePong:{
            [self pongWithTag:tag error:nil];
            break;
        }
        default:{
            break;
        }
    }
}

- (void)ioFrameChannel:(PTChannel*)channel didEndWithError:(NSError*)error {
    if (self.connectedDeviceID && [self.connectedDeviceID isEqualToNumber:channel.userInfo]) {
        [self didDisconnectFromDevice:self.connectedDeviceID];
    }
    
    if (self.connectedChannel == channel) {
        if(self.delegate){
            [self.delegate onClientConnectionDestroyed];
        }
        self.connectedChannel = nil;
    }
}


#pragma mark - Wired device connections


- (void)startListeningForDevices {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserverForName:PTUSBDeviceDidAttachNotification object:PTUSBHub.sharedHub queue:nil usingBlock:^(NSNotification *note) {
        NSNumber *deviceID = [note.userInfo objectForKey:@"DeviceID"];
        NSLog(@"PTUSBDeviceDidAttachNotification: %@", deviceID);
        
        dispatch_async(self.notConnectedQueue, ^{
            if (!self.connectingToDeviceID || ![deviceID isEqualToNumber:self.connectingToDeviceID]) {
                [self disconnectFromCurrentChannel];
                self.connectingToDeviceID = deviceID;
                self.connectedDeviceProperties = [note.userInfo objectForKey:@"Properties"];
                
                [self enqueueConnectToUSBDevice];
            }
        });
    }];
    
    [nc addObserverForName:PTUSBDeviceDidDetachNotification object:PTUSBHub.sharedHub queue:nil usingBlock:^(NSNotification *note) {
        NSNumber *deviceID = [note.userInfo objectForKey:@"DeviceID"];
        NSLog(@"PTUSBDeviceDidDetachNotification: %@", deviceID);
        
        if ([self.connectingToDeviceID isEqualToNumber:deviceID]) {
            self.connectedDeviceProperties = nil;
            self.connectingToDeviceID = nil;
            if (self.connectedChannel) {
                [self.connectedChannel close];
            }
        }
    }];
}


- (void)didDisconnectFromDevice:(NSNumber*)deviceID {
    NSLog(@"Disconnected from device");
    if ([self.connectedDeviceID isEqualToNumber:deviceID]) {
        [self willChangeValueForKey:@"connectedDeviceID"];
        self.connectedDeviceID = nil;
        [self didChangeValueForKey:@"connectedDeviceID"];
    }
}


- (void)disconnectFromCurrentChannel {
    if (self.connectedDeviceID && self.connectedChannel) {
        [self.connectedChannel close];
        self.connectedChannel = nil;
    }
}


- (void)enqueueConnectToLocalIPv4Port {
    dispatch_async(self.notConnectedQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self connectToLocalIPv4Port];
        });
    });
}


- (void)connectToLocalIPv4Port {
    PTChannel *channel = [PTChannel channelWithDelegate:self];
    channel.userInfo = [NSString stringWithFormat:@"127.0.0.1:%d", QVKeyboardProtocolIPv4PortNumber];
    [channel connectToPort:QVKeyboardProtocolIPv4PortNumber IPv4Address:INADDR_LOOPBACK callback:^(NSError *error, PTAddress *address) {
        if (error) {
            if (error.domain == NSPOSIXErrorDomain && (error.code == ECONNREFUSED || error.code == ETIMEDOUT)) {
                // this is an expected state
            } else {
                NSLog(@"Failed to connect to 127.0.0.1:%d: %@", QVKeyboardProtocolIPv4PortNumber, error);
                
                if(self.delegate){
                    [self.delegate onClientErrorOccurred:[NSString stringWithFormat:@"Failed to connect to 127.0.0.1:%d: %@", QVKeyboardProtocolIPv4PortNumber, error]];
                }
            }
        } else {
            [self disconnectFromCurrentChannel];
            self.connectedChannel = channel;
            channel.userInfo = address;
            
            NSLog(@"Connected to %@", address);
            
            if(self.delegate){
                [self.delegate onClientConnectionCreated];
            }
        }
        [self performSelector:@selector(enqueueConnectToLocalIPv4Port) withObject:nil afterDelay:PTAppReconnectDelay];
    }];
}


- (void)enqueueConnectToUSBDevice {
    dispatch_async(self.notConnectedQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self connectToUSBDevice];
        });
    });
}


- (void)connectToUSBDevice {
    PTChannel *channel = [PTChannel channelWithDelegate:self];
    channel.userInfo = self.connectingToDeviceID;
    channel.delegate = self;
    
    [channel connectToPort:QVKeyboardProtocolIPv4PortNumber overUSBHub:PTUSBHub.sharedHub deviceID:self.connectingToDeviceID callback:^(NSError *error) {
        if (error) {
            if (error.domain == PTUSBHubErrorDomain && error.code == PTUSBHubErrorConnectionRefused) {
//                NSLog(@"Failed to connect to device #%@: %@", channel.userInfo, error);
            } else {
//                NSLog(@"Failed to connect to device #%@: %@", channel.userInfo, error);
            }
            if (channel.userInfo == self.connectingToDeviceID) {
                [self performSelector:@selector(enqueueConnectToUSBDevice) withObject:nil afterDelay:PTAppReconnectDelay];
            }
        } else {
            self.connectedDeviceID = self.connectingToDeviceID;
            self.connectedChannel = channel;
            NSLog(@"Connected to device #%@\n%@", self.connectingToDeviceID, self.connectedDeviceProperties);
        }
    }];
}

@end
