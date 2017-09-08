//
//  ViewController.m
//  MapMobilesearchDemo
//
//  Created by pro1 on 2017/9/8.
//  Copyright © 2017年 kangtian. All rights reserved.
//

#import "MapViewController.h"
#import <MAMapKit/MAMapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapSearchKit/AMapSearchKit.h>

// 自定义大头针 气泡
#import "CustomAnnotationView.h"
#import "CurrentLocationAnnotation.h"
#import "XYQProgressHUD+XYQ.h"
#define kAPIKey @"44825d12a2c375091746b93678b8f5c6"


@interface MapViewController ()<MAMapViewDelegate,AMapSearchDelegate>

// 地图
@property (nonatomic, strong) MAMapView            *mapView;

// 搜索引擎
@property (nonatomic, strong) AMapSearchAPI        *search;

// 大头针
@property (nonatomic, strong) UIImageView          *centerAnnotationView;
// 防止重复点击
@property (nonatomic, assign) BOOL                  isMapViewRegionChangedFromTableView;

@property (nonatomic, assign) BOOL                  isLocated;

// 定位
@property (nonatomic, strong) UIButton             *locationBtn;
// 跟踪模式对应图片
@property (nonatomic, strong) UIImage              *imageLocated;
@property (nonatomic, strong) UIImage              *imageNotLocate;

// 选项卡
@property (nonatomic, strong) UISegmentedControl    *searchTypeSegment;

// 当前选中类型
@property (nonatomic, copy) NSString               *currentType;

// 当前类型下标
@property (nonatomic, copy) NSArray                *searchTypes;

// 数据源
@property (nonatomic, strong) NSMutableArray *searchPoiArray;

@end

@implementation MapViewController


#pragma mark - Utility

/* 根据中心点坐标来搜周边的POI. */
- (void)searchPoiWithCenterCoordinate:(CLLocationCoordinate2D )coord
{
    AMapPOIAroundSearchRequest*request = [[AMapPOIAroundSearchRequest alloc] init];
    
    request.location = [AMapGeoPoint locationWithLatitude:coord.latitude  longitude:coord.longitude];
    
    request.radius   = 500;             /// 搜索范围
    request.types = self.currentType;   ///搜索类型
    request.sortrule = 0;               ///排序规则
    
    [self.search AMapPOIAroundSearch:request];
}

- (void)searchReGeocodeWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    AMapReGeocodeSearchRequest *regeo = [[AMapReGeocodeSearchRequest alloc] init];
    
    regeo.location = [AMapGeoPoint locationWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    regeo.requireExtension = YES;
    
    [self.search AMapReGoecodeSearch:regeo];
}


#pragma mark - MapViewDelegate

- (void)mapView:(MAMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    // 防止重复点击
    if (!self.isMapViewRegionChangedFromTableView && self.mapView.userTrackingMode == MAUserTrackingModeNone)
    {
        [self actionSearchAroundAt:self.mapView.centerCoordinate];
    }
    self.isMapViewRegionChangedFromTableView = NO;
}

#pragma mark - userLocation

- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation
{
    if(!updatingLocation)
        return ;
    
    if (userLocation.location.horizontalAccuracy < 0)
    {
        return ;
    }
    
    // only the first locate used.
    if (!self.isLocated)
    {
        self.isLocated = YES;
        self.mapView.userTrackingMode = MAUserTrackingModeFollow;
        [self.mapView setCenterCoordinate:CLLocationCoordinate2DMake(userLocation.location.coordinate.latitude, userLocation.location.coordinate.longitude)];
        
        [self actionSearchAroundAt:userLocation.location.coordinate];
    }
}

- (void)mapView:(MAMapView *)mapView  didChangeUserTrackingMode:(MAUserTrackingMode)mode animated:(BOOL)animated
{
    if (mode == MAUserTrackingModeNone)
    {
        [self.locationBtn setImage:self.imageNotLocate forState:UIControlStateNormal];
    }
    else
    {
        [self.locationBtn setImage:self.imageLocated forState:UIControlStateNormal];
    }
}

- (void)mapView:(MAMapView *)mapView didFailToLocateUserWithError:(NSError *)error
{
    NSLog(@"error = %@",error);
}



- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id <MAAnnotation>)annotation
{
    
    // 自定义坐标
    if ([annotation isKindOfClass:[CurrentLocationAnnotation class]])
    {
        static NSString *reuseIndetifier = @"CustomAnnotationView";
        CustomAnnotationView *annotationView = (CustomAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:reuseIndetifier];
        if (annotationView == nil)
        {
            annotationView = [[CustomAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuseIndetifier];
        }
        annotationView.image = [UIImage imageNamed:@"HomePage_nearbyBikeRedPacket"];
        // 设置为NO，用以调用自定义的calloutView
        annotationView.canShowCallout = NO;
        
        // 设置中心点偏移，使得标注底部中间点成为经纬度对应点
        annotationView.centerOffset = CGPointMake(0, -18);
        return annotationView;
        
    }
    return nil;
}

/* POI 搜索回调. */
- (void)onPOISearchDone:(AMapPOISearchBaseRequest *)request response:(AMapPOISearchResponse *)response
{
    [XYQProgressHUD hideHUD];
    
    //
    [self.mapView removeAnnotations:self.searchPoiArray];
    [self.searchPoiArray removeAllObjects];
    
    if (response.pois.count == 0)
    {
        return;
    }
    //解析response获取POI信息，具体解析见 Demo
    NSLog(@" >>> %@",response.pois);
    
    [response.pois enumerateObjectsUsingBlock:^(AMapPOI *obj, NSUInteger idx, BOOL *stop) {
        
        // 这里使用了自定义的坐标是为了区分系统坐标 不然蓝点会被替代
        CurrentLocationAnnotation *annotation = [[CurrentLocationAnnotation alloc] init];
        [annotation setCoordinate:CLLocationCoordinate2DMake(obj.location.latitude, obj.location.longitude)];
        [annotation setTitle:[NSString stringWithFormat:@"%@ - %ld米", obj.name, (long)obj.distance]];
        [annotation setSubtitle:obj.address];
        
        [self.searchPoiArray addObject:annotation];
    }];
    
    [self showPOIAnnotations];
}


// 设置地图使其可以显示数组中所有的annotation
- (void)showPOIAnnotations
{
    // 向地图窗口添加一组标注
    [self.mapView addAnnotations:self.searchPoiArray];
    
    if (self.searchPoiArray.count == 1)
    {
        //  如果数组中只有一个则直接设置地图中心为annotation的位置。
        self.mapView.centerCoordinate = [(MAPointAnnotation *)self.searchPoiArray[0] coordinate];
        [self.mapView setZoomLevel:16 animated:NO];
    }
}


#pragma mark - Handle Action

- (void)actionSearchAroundAt:(CLLocationCoordinate2D)coordinate
{
    [self searchReGeocodeWithCoordinate:coordinate];
    [self searchPoiWithCenterCoordinate:coordinate];
    
    [self centerAnnotationAnimimate];
}

// 定位
- (void)actionLocation
{
    if (self.mapView.userTrackingMode == MAUserTrackingModeFollow)
    {
        [self.mapView setUserTrackingMode:MAUserTrackingModeNone animated:YES];
    }
    else
    {
        [self.mapView setCenterCoordinate:self.mapView.userLocation.coordinate animated:YES];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            // 因为下面这句的动画有bug，所以要延迟0.5s执行，动画由上一句产生
            [self.mapView setUserTrackingMode:MAUserTrackingModeFollow animated:YES];
        });
    }
}

// 选中
- (void)actionTypeChanged:(UISegmentedControl *)sender
{
    [XYQProgressHUD showMessage:@"正在定位"];
    self.currentType = self.searchTypes[sender.selectedSegmentIndex];
    [self actionSearchAroundAt:self.mapView.centerCoordinate];
}

#pragma mark - Initialization

- (void)initMapView
{
    self.mapView = [[MAMapView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), self.view.bounds.size.height)];
    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];
    
    self.isLocated = NO;
}

- (void)initSearch
{
    self.search = [[AMapSearchAPI alloc] init];
    self.search.delegate = self;
}

- (void)initCenterView
{
    
    // 自己的坐标
    self.centerAnnotationView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"homePage_wholeAnchor"]];
    self.centerAnnotationView.center = CGPointMake(self.mapView.center.x, self.mapView.center.y - CGRectGetHeight(self.centerAnnotationView.bounds) / 2);
    
    [self.mapView addSubview:self.centerAnnotationView];
}

// 装载数据坐标
-(NSMutableArray *)searchPoiArray
{
    if (!_searchPoiArray) {
        _searchPoiArray = [[NSMutableArray alloc]init];
    }
    return _searchPoiArray;
}


// 定位自己
- (void)initLocationButton
{
    self.imageLocated = [UIImage imageNamed:@"gpssearchbutton"];
    self.imageNotLocate = [UIImage imageNamed:@"gpsnormal"];
    self.locationBtn = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.mapView.bounds) - 40, CGRectGetHeight(self.mapView.bounds) - 50, 32, 32)];
    self.locationBtn.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    self.locationBtn.backgroundColor = [UIColor whiteColor];
    
    self.locationBtn.layer.cornerRadius = 3;
    [self.locationBtn addTarget:self action:@selector(actionLocation) forControlEvents:UIControlEventTouchUpInside];
    [self.locationBtn setImage:self.imageNotLocate forState:UIControlStateNormal];
    
    [self.view addSubview:self.locationBtn];
}

- (void)initSearchTypeView
{
    self.searchTypes = @[@"住宅", @"学校", @"楼宇", @"商场"];
    self.currentType = self.searchTypes.firstObject;
    
    self.searchTypeSegment = [[UISegmentedControl alloc] initWithItems:self.searchTypes];
    self.searchTypeSegment.frame = CGRectMake(6, CGRectGetHeight(self.view.bounds) - 40, CGRectGetWidth(self.mapView.bounds) - 80, 32);
    self.searchTypeSegment.layer.cornerRadius = 3;
    self.searchTypeSegment.backgroundColor = [UIColor whiteColor];
    self.searchTypeSegment.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    self.searchTypeSegment.selectedSegmentIndex = 0;
    [self.searchTypeSegment addTarget:self action:@selector(actionTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.searchTypeSegment];
    
}

/* 移动窗口弹一下的动画 */
- (void)centerAnnotationAnimimate
{
    [UIView animateWithDuration:0.5
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         CGPoint center = self.centerAnnotationView.center;
                         center.y -= 20;
                         [self.centerAnnotationView setCenter:center];}
                     completion:nil];
    
    [UIView animateWithDuration:0.45
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         CGPoint center = self.centerAnnotationView.center;
                         center.y += 20;
                         [self.centerAnnotationView setCenter:center];}
                     completion:nil];
}

#pragma mark - Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [AMapServices sharedServices].apiKey = kAPIKey;
    
    [self initSearch];
    [self initMapView];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self initCenterView];
    [self initLocationButton];
    [self initSearchTypeView];
    
    self.mapView.zoomLevel = 17;              ///缩放级别（默认3-19，有室内地图时为3-20）
    self.mapView.showsUserLocation = YES;    ///是否显示用户位置
    self.mapView.showsCompass =NO;          /// 是否显示指南针
    self.mapView.showsScale = NO;           ///是否显示比例尺
    self.mapView.minZoomLevel =14;          /// 限制最小缩放级别
}



@end
