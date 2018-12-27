//
//  PTMessage.h
//  qiweikeyboardapp
//
//  Created by everettjf on 2018/10/11.
//  Copyright © 2018 everettjf. All rights reserved.
//

#ifndef PTMessage_h
#define PTMessage_h


#import <Foundation/Foundation.h>
#include <stdint.h>

static const int QVKeyboardProtocolIPv4PortNumber = 6921;

enum {
    //
    // -> send to
    // <=> send to and receive from
    //
    
    // ios -> macos
    QVKeyboardFrameTypeDeviceInfo = 1000,
    QVKeyboardFrameTypePong = 1001,
    
    // macos -> ios
    QVKeyboardFrameTypePing = 2000,
    QVKeyboardFrameTypeDeleteBackward = 2001,
    
    // ios <=> macos
    QVKeyboardFrameTypeTextMessage = 3000,
    
};

typedef struct _QVKeyboardTextFrame {
    uint32_t length;
    uint8_t utf8text[0];
} QVKeyboardTextFrame;


static dispatch_data_t QVKeyboardTextDispatchDataWithString(NSString *message) {
    // Use a custom struct
    const char *utf8text = [message cStringUsingEncoding:NSUTF8StringEncoding];
    size_t length = strlen(utf8text);
    QVKeyboardTextFrame *textFrame = CFAllocatorAllocate(nil, sizeof(QVKeyboardTextFrame) + length, 0);
    memcpy(textFrame->utf8text, utf8text, length); // Copy bytes to utf8text array
    textFrame->length = htonl(length); // Convert integer to network byte order
    
    // Wrap the textFrame in a dispatch data object
    return dispatch_data_create((const void*)textFrame, sizeof(QVKeyboardTextFrame)+length, nil, ^{
        CFAllocatorDeallocate(nil, textFrame);
    });
}

#endif /* PTMessage_h */
