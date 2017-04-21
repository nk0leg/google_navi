//
//  ProxyManager.h
//
//  Created by Ford Developer on 10/4/17.
//

#import "SDLStreamingMediaManager.h"
#import "SDLAbstractProtocol.h"
#import "SDLAbstractTransport.h"

@interface sdlProxyManager : NSObject

@property (strong) SDLAbstractProtocol *protocol;
@property (strong) SDLAbstractTransport *transport;
@property (readonly, copy) NSSet *proxyListeners;
@property (copy) NSString *debugConsoleGroupName;
@property (readonly, copy) NSString *proxyVersion;
@property (nonatomic, strong, readonly) SDLStreamingMediaManager *streamingMediaManager;
@property (nonatomic, readonly, getter=isConnected) BOOL connected;


+ (instancetype)sharedManager;
- (void)start;
- (void)stop;

@end
