//
//  ViewController.m
//  QVKeyboardApp
//
//  Created by everettjf on 2018/10/11.
//  Copyright © 2018 everettjf. All rights reserved.
//

#import "ViewController.h"
#import "AboutViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *textView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"USB Keyboard";
}
- (IBAction)settingButtonTapped:(id)sender {
    NSURL *settingUrl = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    
    if([UIDevice currentDevice].systemVersion.integerValue >= 11){
        // >= iOS11
        [[UIApplication sharedApplication] openURL:settingUrl options:@{} completionHandler:^(BOOL success) {}];
    } else {
        // iOS10
        [[UIApplication sharedApplication] openURL:settingUrl];
    }
    
}
- (IBAction)downloadButtonTapped:(id)sender {
    NSURL *site = [NSURL URLWithString:@"https://qvkeyboard.github.io"];
    [[UIApplication sharedApplication] openURL:site options:@{} completionHandler:^(BOOL success) {}];
}

- (IBAction)aboutButtonTapped:(id)sender {
    AboutViewController *vc = [[AboutViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
