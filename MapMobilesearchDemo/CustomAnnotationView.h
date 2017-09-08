//
//  CustomAnnotationView.h
//  MapBuildingDemo
//
//  Created by pro1 on 2017/9/5.
//  Copyright © 2017年 AutoNavi. All rights reserved.
//

#import <MAMapKit/MAMapKit.h>
#import "CustomCalloutView.h"

@interface CustomAnnotationView : MAAnnotationView

@property (nonatomic, readonly) CustomCalloutView *calloutView;

@end
