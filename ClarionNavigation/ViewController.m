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
#import "ProxyManager.h"
#import "SDLManager.h"
#import "NSData+Chunks.h"

typedef NS_ENUM(NSUInteger, RBStreamingType) {
    RBStreamingTypeDevice,
    RBStreamingTypeFile
};

static NSString* const RBVideoStreamingConnectedKeyPath = @"videoSessionConnected";
static void* RBVideoStreamingConnectedContext = &RBVideoStreamingConnectedContext;

static NSString* const RBAudioStreamingConnectedKeyPath = @"audioSessionConnected";
static void* RBAudioStreamingConnectedContext = &RBAudioStreamingConnectedContext;

@interface ViewController () <GMSMapViewDelegate, MainMenuDelegate>

@property (nonatomic, weak) IBOutlet GMSMapView *mapView;
@property (nonatomic, weak) IBOutlet MainMenuView *mainMenu;
@property (nonatomic, weak) IBOutlet UIView *dimmingView;
@property (nonatomic, strong, readwrite, nullable) SDLStreamingMediaManager *streamingMediaManager;
@property (nonatomic, strong) SDLManager *manager;

@property (nonatomic, strong) UIImage *currentScreen;

// Video File Streaming
@property (nonatomic, weak) IBOutlet UISegmentedControl* videoStreamingTypeSegmentedControl;
@property (nonatomic, strong) dispatch_queue_t videoStreamingQueue;
@property (nonatomic, strong) NSData* videoStreamingData;
@property (nonatomic) BOOL endVideoStreaming;
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
    
    
//    ProxyState state = [ProxyManager sharedManager].state;
//    switch (state) {
//        case ProxyStateStopped: {
//            [[ProxyManager sharedManager] startIAP];
//        } break;
//        case ProxyStateSearchingForConnection: {
//            [[ProxyManager sharedManager] reset];
//        } break;
//        case ProxyStateConnected: {
//            [[ProxyManager sharedManager] reset];
//        } break;
//        default: break;
//    }
    self.mainMenu.delegate = self;
}

#pragma mark - Menu

- (void)showMenu:(BOOL)isVisible {
    self.dimmingView.alpha = isVisible ? 0.3 : 0.0;
    self.mainMenu.alpha = isVisible ? 1.0 : 0.0;
}

- (void)menuItemSelected:(MainMenuItemType)itemType {
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
    
//    @try {
//        [[ProxyManager sharedManager] removeObserver:self forKeyPath:NSStringFromSelector(@selector(state))];
//    } @catch (NSException __unused *exception) {}
}

#pragma mark - KVO updates

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
//    if ([keyPath isEqualToString:NSStringFromSelector(@selector(state))]) {
//            ProxyState newState = [change[NSKeyValueChangeNewKey] unsignedIntegerValue];
//            NSLog(@"SDL Proxy state = [%lu]",(unsigned long)newState);
//        }
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
            _recording = false;
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


#pragma mark - SDL Streaming
- (sdlProxyManager*)SDLManager {
    return [sdlProxyManager sharedManager];
}

- (SDLStreamingMediaManager*)streamingManager {
    return self.SDLManager.streamingMediaManager;
}

- (BOOL)isAudioSessionConnected {
    return self.SDLManager.isConnected ? self.streamingManager.audioSessionConnected : NO;
}

- (BOOL)isVideoSessionConnected {
    return self.SDLManager.isConnected ? self.streamingManager.videoSessionConnected : NO;
}


- (void)sdl_handleEmptyStreamingDataError {
    [self sdl_presentErrorWithMessage:@"Cannot start stream. Streaming data is empty."];
}

- (void)sdl_handleProxyNotConnectedError {
    [self sdl_presentErrorWithMessage:@"Cannot start streaming. Not connected to Core."];
}

- (void)sdl_presentErrorWithMessage:(NSString*)message {
//    UIAlertController* alertController = [UIAlertController simpleErrorAlertWithMessage:message];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [self presentViewController:alertController
//                           animated:YES
//                         completion:nil];
//    });
}

- (void)sdl_handleError:(NSError*)error {
    NSString* errorString = error.localizedDescription;
    NSString* systemErrorCode = error.userInfo[@"OSStatus"];
    if ([error.domain isEqualToString:SDLErrorDomainStreamingMediaAudio]) {
        switch (error.code) {
            case SDLStreamingAudioErrorHeadUnitNACK:
                errorString = @"Audio Streaming did not receive acknowledgement from Core.";
                break;
            default:
                break;
        }
    } else if ([error.domain isEqualToString:SDLErrorDomainStreamingMediaVideo]) {
        switch (error.code) {
            case SDLStreamingVideoErrorHeadUnitNACK:
                errorString = @"Video Streaming did not receive acknowledgement from Core.";
                break;
            case SDLStreamingVideoErrorInvalidOperatingSystemVersion:
                errorString = @"Video Streaming can only be run on iOS 8+ devices.";
                break;
            case SDLStreamingVideoErrorConfigurationCompressionSessionCreationFailure:
                errorString = @"Could not create Video Streaming compression session.";
                break;
            case SDLStreamingVideoErrorConfigurationAllocationFailure:
                errorString = @"Could not allocate Video Streaming configuration.";
                break;
            case SDLStreamingVideoErrorConfigurationCompressionSessionSetPropertyFailure:
                errorString = @"Could not set property for Video Streaming configuration.";
                break;
            default:
                break;
        }
    }
    
    if (systemErrorCode) {
        errorString = [NSString stringWithFormat:@"%@ %@", errorString, systemErrorCode];
    }
    
    [self sdl_presentErrorWithMessage:errorString];
}


- (void)sdl_beginVideoStreaming {
    if (self.videoStreamingTypeSegmentedControl.selectedSegmentIndex == RBStreamingTypeDevice) {
//        if (!self.camera) {
//            self.camera = [[RBCamera alloc] initWithDelegate:self];
//        }
        
 //       [self.camera startCapture];
    } else {
        self.videoStreamingQueue = dispatch_queue_create("com.smartdevicelink.videostreaming",
                                                         DISPATCH_QUEUE_SERIAL);
        
//        NSArray* videoChunks = [self.videoStreamingData dataChunksOfSize:self.settingsManager.videoStreamingBufferSize];
        NSInteger videoStreamingBufferSize = 300;
        NSArray* videoChunks = [self.videoStreamingData dataChunksOfSize:videoStreamingBufferSize];
        
        dispatch_async(self.videoStreamingQueue, ^{
            while (!self.endVideoStreaming) {
                for (NSData* chunk in videoChunks) {
                    // We send raw data because there are so many possible types of files,
                    // it's easier for us to just send raw data, and let Core try to
                    // reassemble it. SDLStreamingMediaManager actually takes
                    // CVImageBufferRefs and converts them to NSData and sends them off
                    // using SDLProtocol's sendRawData:withServiceType:.
                    if (self.isVideoSessionConnected) {
                        [self.SDLManager.protocol sendRawData:chunk
                                         withServiceType:SDLServiceType_Video];
                        
                        [NSThread sleepForTimeInterval:0.25];
                    } else {
                        self.endVideoStreaming = YES;
                        break;
                    }
                }
            }
            
            self.endVideoStreaming = NO;
        });
    }
}

- (void)sdl_endVideoStreaming {
    [self.streamingManager stopVideoSession];
//    [self.camera stopCapture];
    
    self.endVideoStreaming = YES;
    self.videoStreamingQueue = nil;
}


- (void)StartVideoStreaming {
    if (self.streamingManager.videoSessionConnected) {
        [self sdl_endVideoStreaming];
    } else {
        if (self.videoStreamingTypeSegmentedControl.selectedSegmentIndex == RBStreamingTypeFile
            && !self.videoStreamingData) {
            [self sdl_handleEmptyStreamingDataError];
            return;
        }
        if (!self.SDLManager.isConnected) {
            [self sdl_handleProxyNotConnectedError];
            return;
        }
        __weak typeof(self) weakSelf = self;
        [self.streamingManager startVideoSessionWithStartBlock:^(BOOL success, NSError * _Nullable error) {
            typeof(weakSelf) strongSelf = weakSelf;
            if (!success) {
                [strongSelf sdl_handleError:error];
            } else {
                [strongSelf sdl_beginVideoStreaming];
            }
        }];
    }
}

@end
