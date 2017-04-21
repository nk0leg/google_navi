//
//  ViewController.m
//  ClarionNavigation
//
//  Created by luxoft iosdev on 09.04.17.
//  Copyright © 2017 Luxoft. All rights reserved.
//
#import <GoogleMaps/GoogleMaps.h>
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "ViewController.h"
#import "MainMenuView.h"
#import "SearchControllerHandler.h"
#import "ClarionSearchController.h"
#import "RoundedView.h"

static CGFloat const kZoomButtonsContainerMaxAlpha = 0.4;
static CGFloat const kLeftButtonsContainerMaxAlpha = 1.0;

@interface ViewController () <GMSMapViewDelegate, MainMenuDelegate, SearchControllerHandlerDelegate>

@property (nonatomic, weak) IBOutlet GMSMapView *mapView;
@property (nonatomic, weak) IBOutlet MainMenuView *mainMenu;
@property (nonatomic, weak) IBOutlet UIView *dimmingView;

@property (nonatomic, strong) ClarionSearchController *searchController;
@property (nonatomic, strong) SearchControllerHandler *searchControllerHandler;
@property (weak, nonatomic) IBOutlet UIView *leftButtonsContainer;
@property (weak, nonatomic) IBOutlet RoundedView *zoomButtonsContainer;
@property (weak, nonatomic) IBOutlet UITableView *searchTableView;

@property (nonatomic, strong) UIImage *currentScreen;
@end

@implementation ViewController {
    BOOL _firstLocationUpdate;
    AVAssetWriter *videoWriter;
    AVAssetWriterInput *videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *avAdaptor;
    NSDate* startedAt;
    void* bitmapData;
    BOOL _recording;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self showMapViewWorkPanels:NO animated:NO];
    [self setupSearchController];
    
    _mapView.camera = [GMSCameraPosition cameraWithLatitude:-33.868
                                                  longitude:151.2086
                                                       zoom:12];
    
    _mapView.settings.compassButton = YES;
    _mapView.settings.myLocationButton = YES;
    _mapView.delegate = self;
    
    // Listen to the myLocation property of GMSMapView.
    [_mapView addObserver:self
               forKeyPath:@"myLocation"
                  options:NSKeyValueObservingOptionNew
                  context:NULL];
    
    // Ask for My Location data after the map has already been added to the UI.
    dispatch_async(dispatch_get_main_queue(), ^{
        _mapView.myLocationEnabled = YES;
    });
    
    videoWriter = nil;
    videoWriterInput = nil;
    avAdaptor = nil;
    startedAt = nil;
    bitmapData = NULL;
    _recording = NO;
	self.currentScreen = nil;

    
    [self performSelector:@selector(startRecording) withObject:nil afterDelay:0.0];
    [_mapView setNeedsDisplay];
    [self performSelector:@selector(stopRecording) withObject:nil afterDelay:10.0];
    
    self.mainMenu.delegate = self;
}

- (void)setupSearchController {
    self.searchController = [[ClarionSearchController alloc] initWithSearchResultsController:nil];
    self.searchControllerHandler = [[SearchControllerHandler alloc] initWithSearchController:self.searchController tableView:self.searchTableView];
    self.searchControllerHandler.delegate = self;
    
    self.navigationItem.titleView = self.searchController.searchBar;    
    self.definesPresentationContext = YES;
}

#pragma mark - SearchControllerHandlerDelegate

- (void)suggestionDidSelect:(NSString *)suggestion {
    NSLog(@"Suggestion did select:%@", suggestion);
}

#pragma mark - TopPanel

- (void)showMapViewWorkPanels:(BOOL)isVisible animated:(BOOL)isAnimated {
    [self.navigationController setNavigationBarHidden:!isVisible animated:isAnimated];
    
    [UIView animateWithDuration:isAnimated ? 0.3 : 0.0 animations:^{
        self.leftButtonsContainer.alpha = isVisible ? kLeftButtonsContainerMaxAlpha : 0.0;
        self.zoomButtonsContainer.alpha = isVisible ? kZoomButtonsContainerMaxAlpha : 0.0;
    }];
}

- (IBAction)menuButtonClicked:(UIBarButtonItem *)sender {
    [self showMenu:YES];
}

- (IBAction)exitButtonClicked:(UIBarButtonItem *)sender {
    NSLog(@"Go to MyApps screen button clicked");
}

#pragma mark - Zoom stepper

- (IBAction)increaseZoomClicked:(UIButton *)sender {
    NSLog(@"Increase zoom clicked");
}

- (IBAction)decreaseZoomClicked:(UIButton *)sender {
    NSLog(@"Decrease zoom clicked");
}

#pragma mark - Left buttons actions

- (IBAction)compassButtonClicked:(UIButton *)sender {
    NSLog(@"Compass button clicked");
}

- (IBAction)currentPositionButtonClicked:(UIButton *)sender {
    NSLog(@"Current position button clicked");
}

#pragma mark - Menu

- (void)showMenu:(BOOL)isVisible {
    self.dimmingView.alpha = isVisible ? 0.3 : 0.0;
    self.mainMenu.alpha = isVisible ? 1.0 : 0.0;
    
    [self showMapViewWorkPanels:!isVisible animated:YES];
}

- (void)menuItemSelected:(MainMenuItemType)itemType {
    switch (itemType) {
        case MainMenuItemTypeSearch:
        {
            [self.searchControllerHandler setSearchActive:YES];
        }
            break;
            
        default:            
            break;
    }
    
    NSLog(@"Menu item selected");
    [self showMenu:NO];
}

- (IBAction)tapOutsideMenu:(id)sender {
    [self showMenu:NO];
}

- (void) viewWillUnload
{
//      [_mapView performSelector:@selector(stopRecording) withObject:nil afterDelay:1.0];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)dealloc {
    [_mapView removeObserver:self
                  forKeyPath:@"myLocation"
                     context:NULL];
}

#pragma mark - KVO updates

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (!_firstLocationUpdate) {
        // If the first location update has not yet been recieved, then jump to that
        // location.
        _firstLocationUpdate = YES;
        CLLocation *location = [change objectForKey:NSKeyValueChangeNewKey];
        _mapView.camera = [GMSCameraPosition cameraWithTarget:location.coordinate
                                                         zoom:14];
    }
}

- (void)mapViewDidStartTileRendering:(GMSMapView *)mapView
{
    NSLog(@"Google start rendering");
    [NSTimer scheduledTimerWithTimeInterval:0.25f
                                     target:self
                                   selector:@selector(writeFrame:)
                                   userInfo:nil
                                    repeats:NO];
}

- (CGContextRef) createBitmapContextOfSize:(CGSize) size {
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
    
    bitmapBytesPerRow   = (size.width * 4);
    bitmapByteCount     = (bitmapBytesPerRow * size.height);
    colorSpace = CGColorSpaceCreateDeviceRGB();
    if (bitmapData != NULL) {
        free(bitmapData);
    }
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL) {
        fprintf (stderr, "Memory not allocated!");
        return NULL;
    }
    
    context = CGBitmapContextCreate (bitmapData,
                                     size.width,
                                     size.height,
                                     8,      // bits per component
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaNoneSkipFirst);
    
    CGContextSetAllowsAntialiasing(context,NO);
    if (context== NULL) {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
        return NULL;
    }
    CGColorSpaceRelease( colorSpace );
    
    return context;
}


- (void) writeFrame: (NSTimer *) timer {
    NSDate* start = [NSDate date];
    UIGraphicsBeginImageContextWithOptions(_mapView.bounds.size, YES, 0);
    [_mapView drawViewHierarchyInRect:_mapView.bounds afterScreenUpdates:YES];
    UIImage *mapSnapShot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    self.currentScreen = mapSnapShot;

    if (_recording) {
        float millisElapsed = [[NSDate date] timeIntervalSinceDate:startedAt] * 1000.0;
        [self writeVideoFrameAtTime:CMTimeMake((int)millisElapsed, 1000)];
    }
    
    float processingSeconds = [[NSDate date] timeIntervalSinceDate:start];
    float delayRemaining = (1.0 / 10.0f) - processingSeconds;
    
    
    //redraw at the specified framerate
    [_mapView performSelector:@selector(setNeedsDisplay) withObject:nil afterDelay:delayRemaining > 0.0 ? delayRemaining : 0.01];
}

- (NSURL*) tempFileURL {
    NSString* outputPath = [[NSString alloc] initWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], @"output.mp4"];
    NSURL* outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError* error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
            NSLog(@"Could not delete old recording file at path:  %@", outputPath);
        }
    }
    return outputURL;
}

-(BOOL) setUpWriter {
    NSError* error = nil;
    videoWriter = [[AVAssetWriter alloc] initWithURL:[self tempFileURL] fileType:AVFileTypeQuickTimeMovie error:&error];
    NSParameterAssert(videoWriter);
    
    //Configure video
    NSDictionary* videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithDouble:1024.0*1024.0], AVVideoAverageBitRateKey,
                                           nil ];
    
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                   AVVideoCodecH264, AVVideoCodecKey,
                                   [NSNumber numberWithInt:self.view.frame.size.width], AVVideoWidthKey,
                                   [NSNumber numberWithInt:self.view.frame.size.height], AVVideoHeightKey,
                                   videoCompressionProps, AVVideoCompressionPropertiesKey,
                                   nil];
    
    videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSParameterAssert(videoWriterInput);
    videoWriterInput.expectsMediaDataInRealTime = YES;
    NSDictionary* bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    avAdaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:videoWriterInput sourcePixelBufferAttributes:bufferAttributes];
    
    //add input
    [videoWriter addInput:videoWriterInput];
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:CMTimeMake(0, 1000)];
    
    return YES;
}

- (void) cleanupWriter {    
    if (bitmapData != NULL) {
        free(bitmapData);
        bitmapData = NULL;
    }
}


- (void) completeRecordingSession {
    @autoreleasepool {
        [videoWriterInput markAsFinished];
        
        // Wait for the video
        int status = videoWriter.status;
        while (status == AVAssetWriterStatusUnknown) {
            NSLog(@"Waiting...");
            [NSThread sleepForTimeInterval:0.5f];
            status = videoWriter.status;
        }
        
        @synchronized(self) {
            BOOL success = [videoWriter finishWriting];
            if (!success) {
                NSLog(@"finishWriting returned NO");
            }
            [self cleanupWriter];
            NSString *outputPath = [[NSString alloc] initWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], @"output.mp4"];
            NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
            
            NSLog(@"Completed recording, file is stored at:  %@", outputURL);
        }
    } //@autoreleasepool
}

- (bool) startRecording {
    bool result = NO;
    @synchronized(self) {
        if (! _recording) {
            result = [self setUpWriter];
            startedAt = [[NSDate date] init];
            _recording = true;
            [NSTimer scheduledTimerWithTimeInterval:0.25f
                                                              target:self
                                                            selector:@selector(writeFrame:)
                                                            userInfo:nil
                                                             repeats:YES];
        }
    }
    
    return result;
}

- (void) stopRecording {
    @synchronized(self) {
        if (_recording) {
            //_recording = false;
            [self completeRecordingSession];
        }
    }
}



-(void) writeVideoFrameAtTime:(CMTime)time {
    if (![videoWriterInput isReadyForMoreMediaData]) {
        NSLog(@"Not ready for video data");
    }
    else {
        @synchronized (self) {
            UIGraphicsBeginImageContext(self.currentScreen.size);
            [self.currentScreen drawInRect:CGRectMake(0, 0, self.currentScreen.size.width, self.currentScreen.size.height)];
            UIImage *newFrame = UIGraphicsGetImageFromCurrentImageContext();
            
            CGImageRef cgImage = CGImageCreateCopy([newFrame CGImage]);
            UIGraphicsEndImageContext();
            
            BOOL success = [avAdaptor appendPixelBuffer:[self pixelBufferFromCGImage: cgImage] withPresentationTime:time];
            if (!success) {
                NSLog(@"Warning:  Unable to write buffer to video");
            }
            
            CGImageRelease(cgImage);
        }
        
    }
    
}
- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    CGFloat width =  ceilf( CGImageGetWidth(image)/100.0f)*100;
    CGSize frame_size = CGSizeMake(400, CGImageGetHeight(image));
    NSDictionary *options = @{
                              (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
                              (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                              };
    
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, frame_size.width,
                                           frame_size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    if (status!=kCVReturnSuccess) {
        NSLog(@"Operation failed");
    }
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, frame_size.width,
                                                 frame_size.height, 8, 4*frame_size.width, rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    
   /* CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGAffineTransform flipVertical = CGAffineTransformMake( 1, 0, 0, -1, 0, CGImageGetHeight(image) );
    CGContextConcatCTM(context, flipVertical);
    CGAffineTransform flipHorizontal = CGAffineTransformMake( -1.0, 0.0, 0.0, 1.0, CGImageGetWidth(image), 0.0 );
    CGContextConcatCTM(context, flipHorizontal);*/
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}

@end
