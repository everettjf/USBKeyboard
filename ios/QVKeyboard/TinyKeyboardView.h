//
//  TinyKeyboardView.h
//  QVKeyboard
//
//  Created by everettjf on 2018/10/19.
//  Copyright © 2018 everettjf. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PAAUI.h"

NS_ASSUME_NONNULL_BEGIN


#define TinyKeyboardViewColor1 PAA_RGB(171,175,186);
#define TinyKeyboardViewColor2 PAA_RGB(208,210,217);


@class TinyKeyboardView;

@protocol TinyKeyboardViewDelegate <NSObject>

@required
- (void)TinyKeyboardView:(TinyKeyboardView*)keyboardView characterTapped:(NSString*)character;

@end

@interface TinyKeyboardView : UIView

@property (nonatomic, weak) id<TinyKeyboardViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
