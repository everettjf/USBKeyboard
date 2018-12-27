//
//  KeyboardViewController.m
//  QVKeyboard
//
//  Created by everettjf on 2018/10/11.
//  Copyright © 2018 everettjf. All rights reserved.
//

#import "KeyboardViewController.h"
#import "QVConnectionManager.h"
#import "Masonry.h"
#import "TinyKeyboardView.h"
#include <pthread.h>

@interface KeyboardViewController () <QVConnectionManagerDelegate,TinyKeyboardViewDelegate>
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *buttonView;

@property (nonatomic, strong) TinyKeyboardView *tinyView;

@property (nonatomic, strong) UIButton *nextKeyboardButton;
@property (nonatomic, strong) UIButton *tinyKeyboardButton;
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIButton *returnButton;

@property (nonatomic, strong) UILabel *textLabel;

@end

@implementation KeyboardViewController

- (void)updateViewConstraints {
    [super updateViewConstraints];
    
    // Add custom view sizing constraints here
}

- (BOOL)fullAccessAvailable{
    static BOOL hasfullAccess = YES;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(@available(iOS 11.0,*)){
            hasfullAccess = [self hasFullAccess];
        }else{
            if([UIPasteboard generalPasteboard]){
                hasfullAccess = YES;
            }else{
                hasfullAccess = NO;
            }
        }
    });
    return hasfullAccess;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupUI];

    if(! [self fullAccessAvailable]){
        for(UIView * view in self.contentView.subviews){
            view.hidden = YES;
        }
        UITextView *textView = [[UITextView alloc] init];
        textView.backgroundColor = [UIColor clearColor];
        textView.editable = NO;
        textView.selectable = NO;
        textView.font = [UIFont systemFontOfSize:16];
        [self.contentView addSubview:textView];
        [textView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(self.contentView);
        }];
        textView.text = @"Please go to Settings > General > Keyboard > Keyboards > USB Keyboard, and make sure Allow Full Access is on.";
        
        [self.contentView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.mas_greaterThanOrEqualTo(120);
        }];
    }
    
    [self showStatusText:@"..."];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    NSLog(@"appear");

    if([self fullAccessAvailable]){
        [QVConnectionManager sharedManager].delegate = self;
        [[QVConnectionManager sharedManager] start];
    }
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    NSLog(@"disappear");
    [[QVConnectionManager sharedManager] stop];

}
- (void)dealloc{
    NSLog(@"dealloc");
}

- (void)setupUI{
    self.contentView = [[UIView alloc] init];
    [self.view addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.view);
        make.top.mas_equalTo(self.view);
        make.right.mas_equalTo(self.view);
    }];
    
    
    UIView *seperator = [[UIView alloc] init];
    seperator.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:seperator];
    [seperator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.view);
        make.right.mas_equalTo(self.view);
        make.top.mas_equalTo(self.contentView.mas_bottom);
        make.height.mas_equalTo(1);
    }];
    
    self.buttonView = [[UIView alloc] init];
    [self.view addSubview:self.buttonView];
    [self.buttonView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.view);
        make.right.mas_equalTo(self.view);
        make.bottom.mas_equalTo(self.view);
        make.height.mas_equalTo(40);
        make.top.mas_equalTo(seperator.mas_bottom);
    }];
    
    {
        self.nextKeyboardButton = [[UIButton alloc]init];
        [self.nextKeyboardButton setTitle:NSLocalizedString(@"Next", @"Title for 'Next Keyboard' button") forState:UIControlStateNormal];
        [self.nextKeyboardButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.nextKeyboardButton addTarget:self action:@selector(handleInputModeListFromView:withEvent:) forControlEvents:UIControlEventAllTouchEvents];
        self.nextKeyboardButton.backgroundColor = TinyKeyboardViewColor1;
        [self.buttonView addSubview:self.nextKeyboardButton];
        
        self.tinyKeyboardButton = [[UIButton alloc]init];
        [self.tinyKeyboardButton setTitle:NSLocalizedString(@"Tiny", @"Title for 'Tiny Keyboard' button") forState:UIControlStateNormal];
        [self.tinyKeyboardButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.tinyKeyboardButton addTarget:self action:@selector(buttonTinyKeyboardTapped:) forControlEvents:UIControlEventTouchUpInside];
        self.tinyKeyboardButton.backgroundColor = TinyKeyboardViewColor2;
        [self.buttonView addSubview:self.tinyKeyboardButton];
        
        self.deleteButton = [[UIButton alloc]init];
        [self.deleteButton setTitle:NSLocalizedString(@"Delete", @"Title for 'Delete' button") forState:UIControlStateNormal];
        [self.deleteButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.deleteButton addTarget:self action:@selector(buttonBackwardTapped:) forControlEvents:UIControlEventTouchUpInside];
        self.deleteButton.backgroundColor = TinyKeyboardViewColor1;
        [self.buttonView addSubview:self.deleteButton];
        
        self.returnButton = [[UIButton alloc]init];
        [self.returnButton setTitle:NSLocalizedString(@"Return", @"Title for 'Return' button") forState:UIControlStateNormal];
        [self.returnButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [self.returnButton addTarget:self action:@selector(buttonReturnTapped:) forControlEvents:UIControlEventTouchUpInside];
        self.returnButton.backgroundColor = TinyKeyboardViewColor2;
        [self.buttonView addSubview:self.returnButton];
        
        BOOL needSwitchKey = YES;
        if (@available(iOS 11.0,*)) {
            needSwitchKey = [self needsInputModeSwitchKey];
        }
        
        if(needSwitchKey){
            [self.nextKeyboardButton mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.mas_equalTo(self.buttonView);
                make.top.mas_equalTo(self.buttonView);
                make.bottom.mas_equalTo(self.buttonView);
            }];
            
            [self.tinyKeyboardButton mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.mas_equalTo(self.nextKeyboardButton.mas_right);
                make.top.mas_equalTo(self.buttonView);
                make.bottom.mas_equalTo(self.buttonView);
                make.width.mas_equalTo(self.nextKeyboardButton);
            }];
            
        }else{
            [self.tinyKeyboardButton mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.mas_equalTo(self.buttonView);
                make.top.mas_equalTo(self.buttonView);
                make.bottom.mas_equalTo(self.buttonView);
            }];
        }
        
        [self.deleteButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(self.tinyKeyboardButton.mas_right);
            make.top.mas_equalTo(self.buttonView);
            make.bottom.mas_equalTo(self.buttonView);
            make.width.mas_equalTo(self.tinyKeyboardButton);
        }];
        
        [self.returnButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(self.deleteButton.mas_right);
            make.top.mas_equalTo(self.buttonView);
            make.right.mas_equalTo(self.buttonView);
            make.bottom.mas_equalTo(self.buttonView);
            make.width.mas_equalTo(self.deleteButton);
        }];
    }
    
    {
        self.textLabel = [[UILabel alloc] init];
        self.textLabel.numberOfLines = 0;
        self.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        self.textLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:self.textLabel];
        [self.textLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.contentView.mas_left);
            make.top.equalTo(self.contentView.mas_top).offset(20);
            make.bottom.equalTo(self.contentView.mas_bottom).offset(-20);
            make.right.equalTo(self.contentView.mas_right);
        }];
    }

    UIColor *textColor = [UIColor blackColor];
    [self.nextKeyboardButton setTitleColor:textColor forState:UIControlStateNormal];
    [self.tinyKeyboardButton setTitleColor:textColor forState:UIControlStateNormal];
    [self.deleteButton setTitleColor:textColor forState:UIControlStateNormal];
    [self.returnButton setTitleColor:textColor forState:UIControlStateNormal];
}

- (void)textWillChange:(id<UITextInput>)textInput {
    // The app is about to change the document's contents. Perform any preparation here.
}

- (void)textDidChange:(id<UITextInput>)textInput {
    // The app has just changed the document's contents, the document context has been updated.
    
}

- (void)buttonBackwardTapped:(id)sender{
    [self.textDocumentProxy deleteBackward];
}

- (void)buttonTinyKeyboardTapped:(id)sender{
    
    if (self.tinyView) {
        [self.tinyView removeFromSuperview];
        self.tinyView = nil;
        self.contentView.hidden = NO;
    } else {
        self.tinyView = [[TinyKeyboardView alloc] init];
        self.tinyView.delegate = self;
        [self.view addSubview:self.tinyView];
        [self.tinyView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
        self.contentView.hidden = YES;
    }
}

- (void)buttonReturnTapped:(id)sender{
    [self.textDocumentProxy insertText:@"\n"];
}

- (void)showStatusText:(NSString*)text {
    if(pthread_main_np()){
        self.textLabel.text = text;
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            self.textLabel.text = text;
        });
    }
}

- (void) onConnectionListening {
    [self showStatusText:@"🤔Waiting for connect..."];

}
- (void) onConnectionCreated {
    [self showStatusText:@"🌈Ready for type :)"];

}
- (void) onConnectionDestroyed{
    [self showStatusText:@"🤔Waiting for connect...."];
}
- (void) onConnectionReceivedTextMessage:(NSString*)message{
    [self.textDocumentProxy insertText:message];
}
- (void)onConnectionReceivedDeleteBackward{
    [self.textDocumentProxy deleteBackward];
}

- (void) onConnectionErrorOccurred:(NSString*)error{
    [self showStatusText:error];
}

- (void)TinyKeyboardView:(TinyKeyboardView *)keyboardView characterTapped:(NSString *)character{
    [self.textDocumentProxy insertText:character];
}

@end
