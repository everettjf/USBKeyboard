//
//  AppDelegate.m
//  QVKeyboardClient
//
//  Created by everettjf on 2018/10/11.
//  Copyright © 2018 everettjf. All rights reserved.
//

#import "AppDelegate.h"
#import "QVClientManager.h"
#import <QuartzCore/QuartzCore.h>

@interface AppDelegate ()<QVClientManagerDelegate,NSTextViewDelegate,NSTextFieldDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *inputTextField;
@property (weak) IBOutlet NSButton *checkBoxAutoReturn;
@property (weak) IBOutlet NSTextField *labelStatus;
@property (weak) IBOutlet NSTabView *tabView;
@property (unsafe_unretained) IBOutlet NSTextView *inputTextView;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Delete key detect
    self.inputTextView.delegate = self;
    self.inputTextField.delegate = self;
    
    // Init ui
    [self showStatusText:@"🤔Waiting for iPhone to connect..."];

    [self.window makeFirstResponder:self.inputTextField];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [QVClientManager sharedManager].delegate = self;
        [[QVClientManager sharedManager] start];
    });
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
    return YES;
}

- (IBAction)textFieldSentAction:(id)sender {
    // send return when no content in single line text
    if(self.inputTextField.stringValue.length == 0){
        [[QVClientManager sharedManager] sendMessage:@"\n" callback:^(BOOL succeed) {}];
        return;
    }
    
    [self sendToPhone];
}

- (IBAction)returnButtonClicked:(id)sender {
    [[QVClientManager sharedManager] sendMessage:@"\n" callback:^(BOOL succeed) {}];
}
- (IBAction)deleteButtonClicked:(id)sender {
    [[QVClientManager sharedManager] sendDeleteBackward:^(BOOL succeed) {}];
}
- (IBAction)sendToiPhoneClicked:(id)sender {
    [self sendToPhone];
}

- (void)sendToPhone{
    BOOL autoReturn = self.checkBoxAutoReturn.state == NSControlStateValueOn;
    BOOL singleLine = [self.tabView.selectedTabViewItem.label containsString:@"Single Line"];
    
    NSString *message;
    if(singleLine){
        message = self.inputTextField.stringValue;
    }else{
        message = self.inputTextView.string;
    }
    
    if(message.length == 0){
        return;
    }
    
    [[QVClientManager sharedManager] sendMessage:message callback:^(BOOL succeed) {
        if(!succeed){
            return;
        }
        if(autoReturn){
            [[QVClientManager sharedManager] sendMessage:@"\n" callback:^(BOOL succeed) {}];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(singleLine){
                self.inputTextField.stringValue = @"";
            }else{
                self.inputTextView.string = @"";
            }
        });
    }];
}

- (void)showStatusText:(NSString*)text{
    self.labelStatus.stringValue = text;
}

- (void)onClientDeviceInfo:(NSDictionary*)info{
    [self showStatusText:@"🌈Ready for typing :)"];
}
- (void)onClientTextMessage:(NSString*)message{
    [self showStatusText:message];
}
- (void)onClientConnectionCreated{
}
- (void)onClientConnectionDestroyed{
    [self showStatusText:@"🤔Waiting for iPhone to connect..."];
}
- (void)onClientErrorOccurred:(NSString*)error{
    [self showStatusText:error];
}
- (IBAction)menuItemIssue:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/qvkeyboard/qvkeyboard/issues"]];
}
- (IBAction)menuItemAuthor:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://everettjf.github.io"]];
}
- (IBAction)menuItemHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://qvkeyboard.github.io"]];
}


#pragma mark NSTextViewDelegate

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector{
    if (commandSelector == @selector(deleteBackward:)) {
        NSLog(@"textview delete key");
        if (self.inputTextView.string.length == 0) {
            [[QVClientManager sharedManager] sendDeleteBackward:^(BOOL succeed) {}];
        }
    }
    return NO;
}

#pragma mark NSTextFieldDelegate
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(deleteBackward:)) {
        NSLog(@"textfield delete key");
        if (self.inputTextField.stringValue.length == 0) {
            [[QVClientManager sharedManager] sendDeleteBackward:^(BOOL succeed) {}];
        }
    }
    return NO;
}

@end
