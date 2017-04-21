//
//  sdlProxyManager.m
//
//  Created by Ford Developer on 10/4/17.
//

#import <Foundation/Foundation.h>
#import "ProxyManager.h"

@import SmartDeviceLink_iOS;

#warning TODO: Change these to match your app settings!!
// App configuration
static NSString *const AppName = @"ClarionNavigation";
static NSString *const AppId = @"8675309";
static const BOOL AppIsMediaApp = NO;
static NSString *const ShortAppName = @"Navi";
static NSString *const AppVrSynonym = @"Hello Navi";
static NSString *const IconFile = @"sdl_icon.png";

// Welcome message
static NSString *const WelcomeShow = @"Welcome to Clarion Navi";
static NSString *const WelcomeSpeak = @"Welcome to Clarion Navi";

// Sample AddCommand
static NSString *const TestCommandName = @"Test Command";
static const NSUInteger TestCommandID = 1;

@interface sdlProxyManager () <SDLManagerDelegate>

@property (nonatomic, strong) SDLManager *manager;
@property (strong, nonatomic) NSMutableSet *mutableProxyListeners;
@property (nonatomic, strong) SDLLifecycleConfiguration *lifecycleConfiguration;
@property (nonatomic, assign, getter=isGraphicsSupported) BOOL graphicsSupported;
@property (nonatomic, assign, getter=isFirstHmiNotNone) BOOL firstHmiNotNone;
@property (nonatomic, assign, getter=isVehicleDataSubscribed) BOOL vehicleDataSubscribed;

@end

@implementation sdlProxyManager

#pragma mark Lifecycle

/**
 *  Singleton method.
 */
+ (instancetype)sharedManager {
    static sdlProxyManager *proxyManager = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
      proxyManager = [[self alloc] init];
    });

    return proxyManager;
}

- (instancetype)init {
    if (self = [super init]) {
        _graphicsSupported = NO;
        _firstHmiNotNone = YES;
        _vehicleDataSubscribed = NO;
        
        // If connecting via USB (to a vehicle).
        _lifecycleConfiguration = [SDLLifecycleConfiguration defaultConfigurationWithAppName:AppName appId:AppId];
        
        _lifecycleConfiguration.appType = [SDLAppHMIType NAVIGATION];
        _lifecycleConfiguration.shortAppName = ShortAppName;
        _lifecycleConfiguration.voiceRecognitionCommandNames = @[AppVrSynonym];
        _lifecycleConfiguration.ttsName = [SDLTTSChunk textChunksFromString:AppName];

        UIImage* appIcon = [UIImage imageNamed:IconFile];
        if (appIcon) {
            _lifecycleConfiguration.appIcon = [SDLArtwork artworkWithImage:appIcon name:IconFile asImageFormat:SDLArtworkImageFormatPNG];
        }
        
        // SDLConfiguration contains the lifecycle and lockscreen configurations
        SDLConfiguration *configuration = [SDLConfiguration configurationWithLifecycle:_lifecycleConfiguration lockScreen:[SDLLockScreenConfiguration enabledConfiguration]];
        
        _manager = [[SDLManager alloc] initWithConfiguration:configuration delegate:self];
        
        [self sdl_addRPCObservers];
    }
    return self;
}

#pragma mark Proxy Lifecycle

/**
 *  Start listening for SDL connections. Use only one of the following connection methods.
 */
- (void)start {
    NSLog(@"starting proxy manager");
    [self.manager startWithReadyHandler:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"There was an error! %@", error.localizedDescription);
            return;
        }
        
        NSLog(@"Successfully connected!");
        [self sdl_addPermissionManagerObservers];
    }];
}

/**
 *  Disconnect and destroy the current proxy.
 */
- (void)stop {
    NSLog(@"stopping proxy manager");
    [self.manager stop];
}


#pragma mark - SDLManagerDelegate
- (void)hmiLevel:(SDLHMILevel *)oldLevel didChangeToLevel:(SDLHMILevel *)newLevel {
    NSLog(@"HMIStatus notification from SDL");
    
    // Send AddCommands in first non-HMI NONE state (i.e., FULL, LIMITED, BACKGROUND)
    if (![newLevel isEqualToEnum:[SDLHMILevel NONE]] && self.isFirstHmiNotNone == YES) {
        _firstHmiNotNone = NO;
        [self sdl_addCommands];
        
        // Other app setup (SubMenu, CreateChoiceSet, etc.) would go here
        // NOTE: Keep the number of RPCs small, as there is a limit in HMI_NONE!
    }
    
    // Send welcome message on first HMI FULL
    if ([newLevel isEqualToEnum:[SDLHMILevel FULL]]) {
        if ([oldLevel isEqualToEnum:[SDLHMILevel NONE]]) {
            [self sdl_performWelcomeMessage];
            return;
        }
        
        // Other HMI (Show, PerformInteraction, etc.) would go here
    }
}

- (void)managerDidDisconnect {
    NSLog(@"Manager did disconnect");
    _firstHmiNotNone = YES;
    _vehicleDataSubscribed = NO;
    _graphicsSupported = NO;
}

#pragma mark - Observers
- (void)sdl_addRPCObservers {
    // Adding Response Observers
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveRegisterAppInterfaceResponse:) name:SDLDidReceiveRegisterAppInterfaceResponse object:nil];
    
    // Adding Notification Observers
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveVehicleData:) name:SDLDidReceiveVehicleDataNotification object:nil];
}

- (void)sdl_addPermissionManagerObservers {
    // Adding Permission Manager Observers
    // Since we do not want to remove the observer, we will not store the UUID it returns
    __weak typeof(self) weakSelf = self;
    [self.manager.permissionManager addObserverForRPCs:@[@"SubscribeVehicleData"] groupType:SDLPermissionGroupTypeAllAllowed withHandler:^(NSDictionary<SDLPermissionRPCName,NSNumber<SDLBool> *> * _Nonnull change, SDLPermissionGroupStatus status) {
        if (status != SDLPermissionGroupStatusAllowed) {
            return;
        }
        
        typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf.isVehicleDataSubscribed == NO) {
            [strongSelf sdl_subscribeVehicleData];
        }
    }];
}

- (void)didReceiveVehicleData:(SDLRPCNotificationNotification *)notification {
    SDLOnVehicleData *onVehicleData = notification.notification;
    if (!onVehicleData || ![onVehicleData isKindOfClass:SDLOnVehicleData.class]) {
        return;
    }
    
    NSLog(@"OnVehicleData notification from SDL");
    
    // TODO: Put your vehicle data code here!
    NSLog(@"Speed: %@", onVehicleData.speed);
}

- (void)didReceiveRegisterAppInterfaceResponse:(SDLRPCResponseNotification *)notification {
    SDLRegisterAppInterfaceResponse *response = notification.response;
    if (!response || ![response isKindOfClass:SDLRegisterAppInterfaceResponse.class]) {
        return;
    }
    
    _graphicsSupported = response.displayCapabilities.graphicSupported.boolValue;
    
    if (self.isGraphicsSupported) {
        // Send images via SDLFileManager
    }
}

#pragma mark - Subscribers & HMI Setup
#pragma mark Vehicle Data
/**
 Subscribe to (periodic) vehicle data updates from SDL.
 */
- (void)sdl_subscribeVehicleData {
    NSLog(@"sdl_subscribeVehicleData");
    if (self.isVehicleDataSubscribed) {
        return;
    }
    
    SDLSubscribeVehicleData *subscribe = [[SDLSubscribeVehicleData alloc] init];
    
    // TODO: Add the vehicle data items you want to subscribe to
    // Specify which items to subscribe to
    subscribe.speed = @YES;
    
    [self.manager sendRequest:subscribe withResponseHandler:^(__kindof SDLRPCRequest * _Nullable request, __kindof SDLRPCResponse * _Nullable response, NSError * _Nullable error) {
        if ([response.resultCode isEqualToEnum:[SDLResult SUCCESS]]) {
            NSLog(@"Vehicle Data Subscribed!");
            _vehicleDataSubscribed = YES;
        }
    }];
}

#pragma mark HMI

/**
 Send welcome message (Speak and Show).
 */
- (void)sdl_performWelcomeMessage {
    NSLog(@"Send welcome message");
    SDLShow *show = [[SDLShow alloc] initWithMainField1:WelcomeShow mainField2:nil alignment:[SDLTextAlignment CENTERED]];
    [self.manager sendRequest:show];
    
    SDLSpeak *speak = [[SDLSpeak alloc] initWithTTS:WelcomeSpeak];
    [self.manager sendRequest:speak];
}

#pragma mark Commands

/**
 Add commands for the app on SDL.
 */
- (void)sdl_addCommands {
    NSLog(@"sdl_addCommands");
    __weak typeof(self) weakSelf = self;
    SDLAddCommand* command = [[SDLAddCommand alloc] initWithId:TestCommandID vrCommands:@[TestCommandName] menuName:TestCommandName handler:^(__kindof SDLRPCNotification * _Nonnull notification) {
        if (![notification isKindOfClass:SDLOnCommand.class]) {
            return;
        }
        
        typeof(weakSelf) strongSelf = weakSelf;
        
        SDLOnCommand* onCommand = (SDLOnCommand *)notification;
        
        if (onCommand.cmdID.unsignedIntegerValue == TestCommandID) {
            SDLShow *show = [[SDLShow alloc] initWithMainField1:@"Test Command" mainField2:nil alignment:[SDLTextAlignment CENTERED]];
            [strongSelf.manager sendRequest:show];
            
            SDLSpeak* speak = [[SDLSpeak alloc] initWithTTS:@"Test Command"];
            [strongSelf.manager sendRequest:speak];
        }
    }];
    
    [self.manager sendRequest:command withResponseHandler:^(__kindof SDLRPCRequest * _Nullable request, __kindof SDLRPCResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"AddCommand response from SDL: %@ with info: %@", response.resultCode.value, response.info);
    }];
}


@end
