//
//  AppDelegate.m
//  MapMobilesearchDemo
//
//  Created by pro1 on 2017/9/8.
//  Copyright © 2017年 kangtian. All rights reserved.
//

#import "AppDelegate.h"
#import <AMapFoundationKit/AMapFoundationKit.h>

#define kAPIKey @"44825d12a2c375091746b93678b8f5c6"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
 
    [AMapServices sharedServices].apiKey = kAPIKey;
    return YES;
}

@end
