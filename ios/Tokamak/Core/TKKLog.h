//
//  TKKLog.h
//  Bumblebee
//
//  Created by everettjf on 2018/4/17.
//  Copyright © 2018年 everettjf. All rights reserved.
//

#import <Foundation/Foundation.h>


#ifdef DEBUG
    #define TKKLog NSLog
#else
    #define TKKLog
#endif


