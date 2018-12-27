//
//  AboutViewController.m
//  QVKeyboardApp
//
//  Created by everettjf on 2018/10/15.
//  Copyright © 2018 everettjf. All rights reserved.
//

#import "AboutViewController.h"
#import "PAAListViewController.h"
#import <UIView+Toast.h>

@interface AboutViewController ()

@end

@implementation AboutViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationItem.title = @"About";
    self.view.backgroundColor = [UIColor whiteColor];
    
    
    NSString *shortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *buildVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *appVersion = [NSString stringWithFormat:@"%@.%@",shortVersion,buildVersion];
    
    
    __weak typeof(self) wself = self;
    self.groups = @[
                    @{
                        @"title":@"General",
                        @"rows" : @[
                                @{
                                    @"title":@"User Guide",
                                    @"action":^(){
                                        [wself openInBrowser:@"https://qvkeyboard.github.io"];
                                    },
                                    },
                                ]
                        },
                    @{
                        @"title":@"Feedback",
                        @"rows" : @[
                                @{
                                    @"title":@"Email",
                                    @"action":^(){
                                        [wself openURL:@"mailto://everettjf@live.com"];
                                    },
                                    },
                                ]
                        },
                    @{
                        @"title":@"Author",
                        @"rows" : @[
                                @{
                                    @"title":@"Twitter",
                                    @"action":^(){
                                        [wself openInBrowser:@"https://twitter.com/everettjf"];
                                    },
                                    },
                                @{
                                    @"title":@"Weibo",
                                    @"action":^(){
                                        [wself openInBrowser:@"https://weibo.com/everettjf"];
                                    },
                                    },
                                @{
                                    @"title":@"Blog",
                                    @"action":^(){
                                        [wself openInBrowser:@"https://everettjf.github.io"];
                                    },
                                    },
                                ]
                        },
                    @{
                        @"title":@"More",
                        @"rows" : @[
                                @{
                                    @"title":[NSString stringWithFormat:@"Version : %@",appVersion],
                                    @"action":^(){
                                    },
                                    },
                                ]
                        },
                    ];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
