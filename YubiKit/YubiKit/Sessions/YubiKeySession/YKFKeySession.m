// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <ExternalAccessory/ExternalAccessory.h>
#import <UIKit/UIKit.h>

#import "YKFKeySession.h"
#import "YKFKeySession+Private.h"
#import "YKFKeySession+Debugging.h"

#import "YubiKitDeviceCapabilities.h"
#import "YKFKeyConnectionController.h"
#import "YKFKeySessionConfiguration.h"
#import "YKFKeyCommandConfiguration.h"
#import "YKFKeyDescription.h"
#import "YKFKVOObservation.h"
#import "YKFBlockMacros.h"
#import "YKFLogger.h"
#import "YKFDispatch.h"
#import "YKFAssert.h"

#import "YKFKeyRawCommandService+Private.h"
#import "YKFKeyOATHService+Private.h"
#import "YKFKeyU2FService+Private.h"
#import "YKFKeyFIDO2Service+Private.h"
#import "YKFKeyDescription+Private.h"
#import "YKFKeyService+Private.h"

#import "EAAccessory+Testing.h"
#import "EASession+Testing.h"

#pragma mark - Private Block Types

typedef void (^YubiKeySessionManagerDispatchBlock)(void);

#pragma mark - Constants

NSString* const YKFKeySessionStatePropertyKey = @"sessionState";
NSString* const YKFKeySessionU2FServicePropertyKey = @"u2fService";
NSString* const YKFKeySessionFIDO2ServicePropertyKey = @"fido2Service";

static NSTimeInterval const YubiKeySessionStartDelay = 0.05; // seconds
static NSTimeInterval const YubiKeySessionStreamOpenDelay = 0.2; // seconds

#pragma mark - YKFKeySession

@interface YKFKeySession()<NSStreamDelegate, YKFKeyServiceDelegate>

// Dispatching

@property (nonatomic) NSOperationQueue *communicationQueue;
@property (nonatomic) dispatch_queue_t sharedDispatchQueue;

// Accessory

@property (nonatomic, readwrite) YKFKeyDescription *keyDescription;

@property (nonatomic) id<YKFEAAccessoryManagerProtocol> accessoryManager;
@property (nonatomic) id<YKFEAAccessoryProtocol> accessory;
@property (nonatomic) id<YKFEASessionProtocol> session;

@property (nonatomic) id<YKFKeyConnectionControllerProtocol> connectionController;

// Services

@property (nonatomic, assign, readwrite) YKFKeySessionState sessionState;

@property (nonatomic, readwrite) id<YKFKeyU2FServiceProtocol, YKFKeyServiceDelegate> u2fService;
@property (nonatomic, readwrite) id<YKFKeyFIDO2ServiceProtocol, YKFKeyServiceDelegate> fido2Service;
@property (nonatomic, readwrite) id<YKFKeyOATHServiceProtocol, YKFKeyServiceDelegate> oathService;
@property (nonatomic, readwrite) id<YKFKeyRawCommandServiceProtocol, YKFKeyServiceDelegate> rawCommandService;

// Observation

@property (nonatomic, assign) BOOL observeAccessoryConnection;
@property (nonatomic, assign) BOOL observeApplicationState;

// Behaviour

@property (nonatomic) id<YKFKeySessionConfigurationProtocol> configuration;
@property (nonatomic) NSString *currentKeyProtocol; // The protocol used to create a communication session with the key.

// Flags

@property (nonatomic, assign) BOOL reconnectOnApplicationActive;

@end

@implementation YKFKeySession

- (instancetype)initWithAccessoryManager:(id<YKFEAAccessoryManagerProtocol>)accessoryManager configuration:(YKFKeySessionConfiguration *)configuration {
    YKFAssertAbortInit(accessoryManager);
    YKFAssertAbortInit(configuration);
    
    self = [super init];
    if (self) {
        self.configuration = configuration;
        self.accessoryManager = accessoryManager;
        
        [self setupCommunicationQueue];
    }
    return self;
}

- (void)dealloc {
    self.observeAccessoryConnection = NO;
    self.observeApplicationState = NO;
}

#pragma mark - Private properties

- (BOOL)isKeyConnected {
    for (EAAccessory *connectedAccessory in self.accessoryManager.connectedAccessories) {
        if ([self shouldAcceptAccessory:connectedAccessory]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Session start/stop

- (void)startSession {
    YKFAssertReturn(YubiKitDeviceCapabilities.supportsMFIAccessoryKey, @"Cannot start the key session on an unsupported device.");
    YKFLogInfo(@"Key Session start requested.");
    
#ifdef DEBUG
    [self checkApplicationConfiguration];
#endif
    
    if (self.sessionState != YKFKeySessionStateClosed) {
        YKFLogInfo(@"Key Session start ignored. The session is already started.");
        return;
    }
    
    self.observeAccessoryConnection = YES;
    self.observeApplicationState = YES;

    [self connectToExistingKey]; // If a key is already plugged, connect to it.
}

- (BOOL)startSessionSync {
    YKFAssertOffMainThread();
    
    YKFAssertReturnValue(YubiKitDeviceCapabilities.supportsMFIAccessoryKey, @"Cannot start the key session on an unsupported device.", NO);
    YKFAssertReturnValue(self.isKeyConnected, @"Cannot start the session if the key is not connected.", NO);
    
    if (self.sessionState == YKFKeySessionStateOpen) {
        return YES;
    }
    
    dispatch_semaphore_t openSemaphore = dispatch_semaphore_create(0);
    
    YKFKVOObservation *observation = [[YKFKVOObservation alloc] initWithTarget:self keyPath:YKFKeySessionStatePropertyKey callback:^(id oldValue, id newValue) {
        YKFKeySessionState newState = ((NSNumber *)newValue).unsignedLongValue;
        if (newState == YKFKeySessionStateOpen) {
            dispatch_semaphore_signal(openSemaphore);
        }
    }];
    YKFAssertReturnValue(observation, @"Could not observe the key session state.", NO);
    
    [self startSession];
    
    YKFKeyCommandConfiguration *configuration = [YKFKeyCommandConfiguration defaultCommandCofiguration];
    dispatch_semaphore_wait(openSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(configuration.commandTimeout * NSEC_PER_SEC)));
    
    observation = nil;
    
    // There was an error when opening the session
    if (self.sessionState != YKFKeySessionStateOpen) {
        return NO;
    }
    
    return YES;
}

- (void)stopSession {
    YKFLogInfo(@"Key Session stop requested.");
    
    if (self.sessionState != YKFKeySessionStateOpen) {
        YKFLogInfo(@"Key Session stop ignored. The session is already stopped.");
        return;
    }

    self.observeAccessoryConnection = NO;
    self.observeApplicationState = NO;

    [self closeSession];
}

- (BOOL)stopSessionSync {
    YKFAssertOffMainThread();
    YKFAssertReturnValue(self.isKeyConnected, @"Cannot stop the session if the key is not connected.", NO);
    
    if (self.sessionState == YKFKeySessionStateClosed) {
        return YES;
    }
        
    dispatch_semaphore_t closeSemaphore = dispatch_semaphore_create(0);
    
    YKFKVOObservation *observation = [[YKFKVOObservation alloc] initWithTarget:self keyPath:YKFKeySessionStatePropertyKey callback:^(id oldValue, id newValue) {
        YKFKeySessionState newState = ((NSNumber *)newValue).unsignedLongValue;
        if (newState == YKFKeySessionStateClosed) {
            dispatch_semaphore_signal(closeSemaphore);
        }
    }];
    YKFAssertReturnValue(observation, @"Could not observe the key session state.", NO);
    
    [self stopSession];
    
    YKFKeyCommandConfiguration *configuration = [YKFKeyCommandConfiguration defaultCommandCofiguration];
    dispatch_semaphore_wait(closeSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(configuration.commandTimeout * NSEC_PER_SEC)));
    
    observation = nil;
    
    // There was an error when closing the session
    if (self.sessionState != YKFKeySessionStateClosed) {
        return NO;
    }
    
    return YES;
}

#pragma mark - Notification subscription

- (void)setObserveApplicationState:(BOOL)observeApplicationState {
    if (_observeApplicationState == observeApplicationState) {
        return;
    }
    _observeApplicationState = observeApplicationState;
    if (_observeApplicationState) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    }
}

- (void)setObserveAccessoryConnection:(BOOL)observeAccessoryConnection {
    if (_observeAccessoryConnection == observeAccessoryConnection) {
        return;
    }
    _observeAccessoryConnection = observeAccessoryConnection;
    if (_observeAccessoryConnection) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidConnect:)
                                                     name:EAAccessoryDidConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidDisconnect:)
                                                     name:EAAccessoryDidDisconnectNotification object:nil];
        
        [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:EAAccessoryDidDisconnectNotification object:nil];
        
        [[EAAccessoryManager sharedAccessoryManager] unregisterForLocalNotifications];
    }
}

- (void)connectToExistingKey {
    for (EAAccessory *connectedAccessory in self.accessoryManager.connectedAccessories) {
        if (![self shouldAcceptAccessory:connectedAccessory]) {
            continue;
        }
        
        NSDictionary *userInfo = @{EAAccessoryKey: connectedAccessory};
        NSNotification *notification = [[NSNotification alloc] initWithName:EAAccessoryDidConnectNotification object:self userInfo:userInfo];
        [self accessoryDidConnect:notification];
        break;
    }
}

#pragma mark - Session state

- (void)setSessionState:(YKFKeySessionState)sessionState {
    // Avoid updating the state if the same to not trigger unnecessary KVO notifications.
    if (sessionState == _sessionState) {
        return;
    }
    _sessionState = sessionState;
}

#pragma mark - Shared communication queue

- (void)setupCommunicationQueue {
    // Create a sequential queue because the YubiKey accepts sequential commands.
    
    self.communicationQueue = [[NSOperationQueue alloc] init];
    self.communicationQueue.maxConcurrentOperationCount = 1;
    
    dispatch_queue_attr_t dispatchQueueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, -1);
    self.sharedDispatchQueue = dispatch_queue_create("com.yubico.YKCommunication", dispatchQueueAttributes);
    
    self.communicationQueue.underlyingQueue = self.sharedDispatchQueue;
}

- (void)dispatchOnSharedQueueBlock:(YubiKeySessionManagerDispatchBlock)block delay:(NSTimeInterval)delay {
    YKFParameterAssertReturn(block);
    YKFParameterAssertReturn(self.sharedDispatchQueue);
    
    if (delay > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), self.sharedDispatchQueue, block);
    } else {
        dispatch_async(self.sharedDispatchQueue, block);
    }
}

- (void)dispatchOnSharedQueueBlock:(YubiKeySessionManagerDispatchBlock)block {
    [self dispatchOnSharedQueueBlock:block delay:0];
}

#pragma mark - Accessory connection

- (void)accessoryDidConnect:(NSNotification *)notification {
    EAAccessory *accessory = [[notification userInfo] objectForKey:EAAccessoryKey];
    if (![self shouldAcceptAccessory:accessory]) {
        return;
    }
    
    self.currentKeyProtocol = [self.configuration keyProtocolForAccessory:accessory];
    YKFAssertReturn(self.currentKeyProtocol != nil, @"Could not find a valid protocol for the accessory.");
    
    YKFLogInfo(@"The YubiKey is connected to the iOS device.");
    
    self.accessory = accessory;
    self.keyDescription = [[YKFKeyDescription alloc] initWithAccessory:self.accessory];
    if (!self.keyDescription) {
        // If a key description could not be fetched, do not start the session.
        return;
    }
    
    self.sessionState = YKFKeySessionStateOpening;
    
    ykf_weak_self();
    [self dispatchOnSharedQueueBlock:^{
        ykf_safe_strong_self();
        BOOL success = [strongSelf openSession];
        if (!success) {
            strongSelf.sessionState = YKFKeySessionStateClosed;
            return;
        }
        
        [strongSelf dispatchOnSharedQueueBlock:^{
            strongSelf.sessionState = YKFKeySessionStateOpen;
        } delay:YubiKeySessionStreamOpenDelay]; // Add a small delay to allow the streams to open.
    }
    delay:YubiKeySessionStartDelay]; // Add a small delay to allow the Key to initialize after connected.
}

- (void)accessoryDidDisconnect:(id)notification {
    if (!self.accessory) { return; }
    
    // Framework bug workaround
    EAAccessory *accessory = [notification isKindOfClass:[EAAccessory class]] ? (EAAccessory*)notification : [[notification userInfo] objectForKey:EAAccessoryKey];
    
    if (accessory.connectionID != self.accessory.connectionID) {
        return;
    }
    
    YKFLogInfo(@"The YubiKey is disconnected from the iOS device.");
    
    self.accessory = nil;
    self.keyDescription = nil;
    
    // Close session will dispatch the cleanup of streams on the dispatch queue.
    [self closeSession];
}

#pragma mark - Application Notifications

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self closeSession];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    if (self.sessionState == YKFKeySessionStateClosed) {
        return;
    }

    __block UIBackgroundTaskIdentifier bgTask = [self.application beginBackgroundTaskWithName:@"CloseSessionTask" expirationHandler:^{
        [self.application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
        YKFLogVerbose(@"Background task expired.");
    }];
    
    if (self.sessionState == YKFKeySessionStateOpen || self.sessionState == YKFKeySessionStateOpening) {
        self.reconnectOnApplicationActive = YES;
        [self closeSession];
    }
    
    // Dispatch a subsequent operation which will wait for closing.
    dispatch_async(self.sharedDispatchQueue, ^{
        [self.application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
        YKFLogVerbose(@"Background task ended.");
    });
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (self.reconnectOnApplicationActive) {
        [self connectToExistingKey];
    }
}

#pragma mark - Session

- (BOOL)openSession {
    YKFAssertOffMainThread();
    YKFAssertReturnValue(self.currentKeyProtocol != nil, @"No known protocol to connect to the key.", NO);

    self.session = [[EASession alloc] initWithAccessory:self.accessory forProtocol:self.currentKeyProtocol];
    
    if (self.session) {
        self.reconnectOnApplicationActive = NO;
        self.connectionController = [[YKFKeyConnectionController alloc] initWithSession:self.session operationQueue:self.communicationQueue];
        self.session.outputStream.delegate = self;
        
        /*
         Setup services after the connection is created
         */
        
        YKFKeyU2FService *u2fService = [[YKFKeyU2FService alloc] initWithConnectionController:self.connectionController];
        u2fService.delegate = self;
        self.u2fService = u2fService;
        
        YKFKeyFIDO2Service *fido2Service = [[YKFKeyFIDO2Service alloc] initWithConnectionController:self.connectionController];
        fido2Service.delegate = self;
        self.fido2Service = fido2Service;
        
        YKFKeyOATHService *oathService = [[YKFKeyOATHService alloc] initWithConnectionController:self.connectionController];
        oathService.delegate = self;
        self.oathService = oathService;
        
        YKFKeyRawCommandService *rawCommandService = [[YKFKeyRawCommandService alloc] initWithConnectionController:self.connectionController];
        rawCommandService.delegate = self;
        self.rawCommandService = rawCommandService;
        
        YKFLogInfo(@"Session opened.");
    } else {
        YKFLogInfo(@"Session opening failed.");
    }
    return self.session != nil;
}

- (void)closeSession {
    if (!self.session) {
        return;
    }
    if (self.sessionState == YKFKeySessionStateClosed || self.sessionState == YKFKeySessionStateClosing) {
        return;
    }
    
    self.sessionState = YKFKeySessionStateClosing;
        
    ykf_weak_self();
    [self.connectionController closeConnectionWithCompletion:^{
        ykf_safe_strong_self();
        
        // Clean services first
        strongSelf.u2fService = nil;
        strongSelf.fido2Service = nil;
        strongSelf.oathService = nil;
        strongSelf.rawCommandService = nil;
        
        strongSelf.connectionController = nil;
        strongSelf.session = nil;
        
        strongSelf.sessionState = YKFKeySessionStateClosed;
        YKFLogInfo(@"Session closed.");
    }];
}

#pragma mark - Commands

- (void)cancelCommands {
    [self.connectionController cancelAllCommands];
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if (eventCode != NSStreamEventErrorOccurred && eventCode != NSStreamEventEndEncountered) {
        return;
    }
    
    // Stream was closed as a part of a normal session shutdown
    if (self.sessionState != YKFKeySessionStateOpen) {
        return;
    }
    
    // Stream  was dropped or externally closed -> close the session to avoid lingering
    YKFLogInfo(@"The communication with the key was closed by the system.");
    [self closeSession];
    
    __block UIApplicationState applicationState = UIApplicationStateActive;
    ykf_dispatch_block_sync_main(^{
        applicationState = self.application.applicationState;
    });
    
    // If the connection was lost in inactive or backgroud states -> mark it for reconnecting again when the application becomes active.
    if (applicationState != UIApplicationStateActive) {
        self.reconnectOnApplicationActive = YES;
    }
}

#pragma mark - YKFKeyServiceDelegate

- (void)keyService:(YKFKeyService *)service willExecuteRequest:(YKFKeyRequest *)request {
    [self.u2fService keyService:service willExecuteRequest:request];
    [self.fido2Service keyService:service willExecuteRequest:request];
    [self.oathService keyService:service willExecuteRequest:request];
    [self.rawCommandService keyService:service willExecuteRequest:request];
}

#pragma mark - Helpers

- (BOOL)shouldAcceptAccessory:(EAAccessory*)accessory {
    YKFParameterAssertReturnValue(accessory, NO);
    return [self.configuration allowsAccessory:accessory];
}

@synthesize application;

@end
