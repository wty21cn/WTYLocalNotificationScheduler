//
//  WTYLocalNotificationScheduler.m
//  WTYLocalNotificationScheduler
//
//  Created by Rain on 16/8/11.
//  Copyright © 2016 Rain Wang. All rights reserved.
//

#import "WTYLocalNotificationScheduler.h"
#import "WTYLocalNotification_Internal.h"
#import <objc/runtime.h>

static WTYLocalNotificationScheduler *sharedScheduler = nil;
static const NSInteger kMaxAllowdScheduledNotifications = 64;
static NSString * const kSavedQueueFileName = @"WTYLocalNotification.queue";
static NSString * const kNotification = @"Notification";
static NSString * const kIndexSet = @"IndexSet";


@interface WTYLocalNotificationScheduler ()

@property (nonatomic, strong) NSMutableArray<WTYLocalNotification *> *queuedNotifications;
@property (nonatomic, strong) NSMutableArray<WTYLocalNotification *> *scheduledNotifications;
@property (nonatomic, strong) NSOperationQueue *synchronizeNotificationOperationQueue;

/**
 *  The queue is sorted ascending by fireDate, this method find the index to insert a new WTYLocalNotification.
 *  
 *  @param queue Specify this paramater to insert notification to queuedNotifications or scheduledNotifications
 *  @param notification A new WTYLocalNotification.
 *
 *  @return The index to insert.
 */
- (NSInteger)indexOfInsertPlaceInQueue:(NSMutableArray<WTYLocalNotification *> *)queue forNotification:(WTYLocalNotification *)notification;

/**
 *  Load queue from archive previously persisted on disk.
 */
- (void)loadQueue;

/**
 *  Get the WTYLocalNotification in queue by identifier
 *
 *  @param identifier WTYLocalNotification identifier
 *
 *  @return NSDictionary containing WTYLocalNotification and its index if identifier is tracked by WTYLocalNotificationScheduler, otherwise nil, if the notification has custom repeat interval, return the TYLocalNotification with nearest fireDate. Use kNotification to access the TYLocalNotification and kIndexSet to access its index.
 */
- (NSDictionary *)notificationWithIdentifierInQueue:(NSString *)identifier;

/**
 *  Get the WTYLocalNotification scheduled by identifier
 *
 *  @param identifier WTYLocalNotification identifier
 *
 *  @return NSDictionary containing WTYLocalNotification and its index if identifier is tracked by WTYLocalNotificationScheduler, otherwise nil, if the notification has custom repeat interval, return the TYLocalNotification with nearest fireDate. Use kNotification to access the TYLocalNotification and kIndexSet to access its index.
 */
- (NSDictionary *)notificationWithIdentifierScheduled:(NSString *)identifier;

@end

@implementation WTYLocalNotificationScheduler


#pragma mark - Scheduling

- (void)synchronizeToUILocalNotificationSystem {
    NSLog(@"%@ is called",NSStringFromSelector(_cmd));
    
    [self.synchronizeNotificationOperationQueue cancelAllOperations];
    
    NSBlockOperation *operation = [[NSBlockOperation alloc] init];
    __weak __typeof(operation) weakOperation = operation;
    
    //Make the current status stable by copying _scheduledNotifications
    NSArray *notifications = [_scheduledNotifications copy];
    [operation addExecutionBlock:^{
        
        for (WTYLocalNotification *n in notifications) {
            if ([weakOperation isCancelled]) break;
            if ([n isSynchronized]) continue;
            n.synchronized = YES;
            dispatch_sync(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] scheduleLocalNotification:n.notification];
            });
        }
    }];
    [self.synchronizeNotificationOperationQueue addOperation:operation];
    [self saveQueue];
}

- (void)scheduleNotificationFromQueue {
    [self updateScheduledNotification];
    [self handleSchedulingNotificationFromQueue];
    [self synchronizeToUILocalNotificationSystem];
}

- (void)handleSchedulingNotificationFromQueue {
    WTYLocalNotification *firstQueued = [_queuedNotifications firstObject];
    while (firstQueued) {
        [_queuedNotifications removeObjectAtIndex:0];
        [self handleSchedulingNotification:firstQueued];
        WTYLocalNotification *nextFirstQueued = [_queuedNotifications firstObject];
        
        // If the first notification is just queued back, then break.
        if ([nextFirstQueued isEqual:firstQueued] && [firstQueued.notification isEqual:nextFirstQueued.notification]) {
            break;
        }
        firstQueued = nextFirstQueued;
    }
}

- (NSString *)scheduleNotification:(WTYLocalNotification *)notification {
    [self updateScheduledNotification];
    [self handleSchedulingNotificationFromQueue];
    notification = [notification copy];
    if (notification.notificationID) {
        return nil;
    }
    NSString *notificationID = [self handleSchedulingNotification:notification];
    [self synchronizeToUILocalNotificationSystem];
    return notificationID;
}

- (NSArray<NSString *> *)scheduleNotifications:(NSArray<WTYLocalNotification *> *)notifications {
    [self updateScheduledNotification];
    NSMutableArray<NSString *> *notificationIDs = [NSMutableArray arrayWithCapacity:notifications.count];
    for (WTYLocalNotification *n in notifications) {
        WTYLocalNotification *notification = [n copy];
        BOOL shouldFiredNow = [notification prepareToBeScheduled];
        if (shouldFiredNow) {
            [[UIApplication sharedApplication] presentLocalNotificationNow:notification.notification];
             notification = [notification notificationOfNextFireDate];
        }
        [notificationIDs addObject:notification.notificationID];
        if (notification) {
            [self.queuedNotifications addObject:notification];
        }
    }
    [self.queuedNotifications sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    [self handleSchedulingNotificationFromQueue];
    [self synchronizeToUILocalNotificationSystem];
    return [notificationIDs copy];
}

- (NSString *)handleSchedulingNotification:(WTYLocalNotification *)notification {
    NSString *notificationID = nil;
    while (notification) {
        BOOL shouldFireNow = [notification prepareToBeScheduled];
        notificationID = notification.notificationID;
        if (self.notificationUpdateBlock) {
            self.notificationUpdateBlock(notification);
        }
        if (shouldFireNow) {
            [[UIApplication sharedApplication] presentLocalNotificationNow:notification.notification];
        } else {
            if ( self.scheduledCount < kMaxAllowdScheduledNotifications) {
                [self addNotificationToScheduledNotifications:notification];
            } else {
                WTYLocalNotification *lastScheduled = [_scheduledNotifications lastObject];
                NSLog(@"notification firedate: %@", notification.fireDate);
                NSLog(@"lastScheduled firedate: %@", lastScheduled.fireDate);
                if ([[lastScheduled fireDate] compare:notification.fireDate] != NSOrderedDescending) {
                    // One notificationID can exist in queue only once. so after add this one, break
                    [self addNotificationToQueuedNotifications:notification];
                    break;
                }
                [_scheduledNotifications removeLastObject];
                [[UIApplication sharedApplication] cancelLocalNotification:lastScheduled.notification];
                [self addNotificationToQueuedNotifications:lastScheduled];
                [self addNotificationToScheduledNotifications:notification];
            }
        }
        // If notification's repeatIntervalUnit is not WTYLNRepeatIntervalUnitNone, then get next notification with next fireDate
        notification = [notification notificationOfNextFireDate];
    }
    return notificationID;
}

- (NSInteger)indexOfInsertPlaceInQueue:(NSMutableArray<WTYLocalNotification *> *)queue forNotification:(WTYLocalNotification *)notification {
    NSInteger startIndex = 0, endIndex = queue.count;
    while (startIndex < endIndex) {
        NSInteger midIndex = (startIndex + endIndex) / 2;
        switch ([notification compare:queue[midIndex]]) {
            case NSOrderedSame:
                return midIndex;
                break;
            case NSOrderedAscending:
                endIndex = midIndex;
                break;
            case NSOrderedDescending:
                startIndex = midIndex + 1;
                break;
        }
    }
    return startIndex;
}

- (void)addNotificationToQueuedNotifications:(WTYLocalNotification *)notification {
    notification.synchronized = NO;
    // One notificationID can exist in queue only once.
    NSDictionary *result = [self notificationWithIdentifierInQueue:notification.notificationID];
    WTYLocalNotification *notificationInQueue = result[kNotification];
    NSIndexSet *indexSet = result[kIndexSet];
    if (notificationInQueue) {
        if ([notification compare:notificationInQueue] == NSOrderedAscending) {
            [_queuedNotifications removeObjectsAtIndexes:indexSet];
        } else {
            return;
        }
    }
    NSInteger index = [self indexOfInsertPlaceInQueue:_queuedNotifications forNotification:notification];
    [_queuedNotifications insertObject:notification atIndex:index];
}

- (void)addNotificationToScheduledNotifications:(WTYLocalNotification *)notification {
    [_scheduledNotifications insertObject:notification
                                      atIndex:[self indexOfInsertPlaceInQueue:_scheduledNotifications
                                                              forNotification:notification]];
}

- (void)updateScheduledNotification {
    // now + defaultTimeZone ? notification.fireDate + notification.timeZone
    NSDate* now = [[NSDate date] dateByAddingTimeInterval:[[NSTimeZone defaultTimeZone] secondsFromGMT]];
    NSMutableArray<WTYLocalNotification *> *tmp = [NSMutableArray arrayWithCapacity:self.scheduledCount];
    // Keep notifications which isn't fired or the fireDate is in the past but haven't been sychronized to iOS local notification system yet.
    for (WTYLocalNotification *n in _scheduledNotifications) {
        if (![n isSynchronized] || [[n.fireDate dateByAddingTimeInterval:[n.timeZone secondsFromGMT]] compare:now] == NSOrderedDescending) {
            [tmp addObject:n];
        }
    }
    _scheduledNotifications = tmp;
}

- (void)cancelNotification:(WTYLocalNotification *)notification {
    [self.synchronizeNotificationOperationQueue cancelAllOperations];
    NSMutableArray<WTYLocalNotification *> *tmp = [NSMutableArray arrayWithCapacity:self.scheduledCount];
    for (WTYLocalNotification *n in _scheduledNotifications) {
        if (![n isEqual:notification]) {
            [tmp addObject:n];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] cancelLocalNotification:n.notification];
            });
        }
    }
    _scheduledNotifications = tmp;
    [_queuedNotifications removeObject:notification];
    [self scheduleNotificationFromQueue];
    [self saveQueue];
}

- (void)cancelNotificationWithIdentifier:(NSString *)identifier {
    [self.synchronizeNotificationOperationQueue cancelAllOperations];
    NSMutableArray<WTYLocalNotification *> *tmp = [NSMutableArray arrayWithCapacity:self.scheduledCount];
    for (WTYLocalNotification *n in _scheduledNotifications) {
        if (![n.notificationID isEqualToString:identifier]) {
            [tmp addObject:n];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] cancelLocalNotification:n.notification];
            });
        }
    }
    _scheduledNotifications = tmp;
    NSIndexSet *indexes = [self notificationWithIdentifierInQueue:identifier][kIndexSet];
    if (indexes) {
        [_queuedNotifications removeObjectsAtIndexes:indexes];
    }
    [self scheduleNotificationFromQueue];
    [self saveQueue];
}

- (void)cancelAllNotifications {
    [self.synchronizeNotificationOperationQueue cancelAllOperations];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    });
    [_scheduledNotifications removeAllObjects];
    [_queuedNotifications removeAllObjects];
    [self saveQueue];
}


#pragma mark

- (WTYLocalNotification *)notificationWithIdentifier:(NSString *)identifier {
    if (!identifier) {
        return nil;
    }
    WTYLocalNotification *n;
    n = [self notificationWithIdentifierScheduled:identifier][kNotification];
    if (n) {
        return n;
    }
    n = [self notificationWithIdentifierInQueue:identifier][kNotification];
    return n;
}

- (NSDictionary *)notificationWithIdentifierScheduled:(NSString *)identifier {
    NSUInteger index = 0;
    for (WTYLocalNotification *n in _scheduledNotifications) {
        if ([n.notificationID isEqualToString:identifier]) {
            return @{kIndexSet:[NSIndexSet indexSetWithIndex:index], kNotification:n};
        }
        index++;
    }
    return  nil;
}

- (NSDictionary *)notificationWithIdentifierInQueue:(NSString *)identifier {
    NSUInteger index = 0;
    for (WTYLocalNotification *n in _queuedNotifications) {
        if ([n.notificationID isEqualToString:identifier]) {
            return @{kIndexSet:[NSIndexSet indexSetWithIndex:index], kNotification:n};
        }
        index++;
    }
    return nil;
}


#pragma mark 

- (void)saveQueue {
    NSString * const savedQueuePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:kSavedQueueFileName];
    [NSKeyedArchiver archiveRootObject:_queuedNotifications toFile:savedQueuePath];
}

- (void)loadQueue {
    NSString * const savedQueuePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:kSavedQueueFileName];
    _queuedNotifications = [NSKeyedUnarchiver unarchiveObjectWithFile:savedQueuePath] ?: [[NSMutableArray<WTYLocalNotification *> alloc] init];
}

- (void)loadScheduledNotifications {
    NSArray<UILocalNotification *> *scheduledNotifications = [[UIApplication sharedApplication] scheduledLocalNotifications];
    _scheduledNotifications = [NSMutableArray arrayWithCapacity:scheduledNotifications.count];
    for (UILocalNotification *n in scheduledNotifications) {
        WTYLocalNotification *notification = [WTYLocalNotification notificationWithUILocalNotification:n];
        if (notification) {
            [_scheduledNotifications addObject:notification];
        }
    }
}

#pragma mark - Singleton

+ (instancetype)sharedScheduler {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedScheduler = [[super allocWithZone:NULL] initSingleton];
    });
    return sharedScheduler;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [WTYLocalNotificationScheduler sharedScheduler];
}

+ (instancetype)new {
    return [WTYLocalNotificationScheduler sharedScheduler];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)init {
    return [WTYLocalNotificationScheduler sharedScheduler];
}

- (instancetype)initSingleton {
    if (self = [super init]) {
        [self loadQueue];
        [self loadScheduledNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleUIApplicationNotification:)
                                                     name:UIApplicationDidFinishLaunchingNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleUIApplicationNotification:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleUIApplicationNotification:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Custom cccessor

- (NSOperationQueue *)synchronizeNotificationOperationQueue {
    if (!_synchronizeNotificationOperationQueue) {
        _synchronizeNotificationOperationQueue = [[NSOperationQueue alloc] init];
        _synchronizeNotificationOperationQueue.maxConcurrentOperationCount = 1;
    }
    return _synchronizeNotificationOperationQueue;
}

- (NSArray<WTYLocalNotification *> *)queuedWTYLocalNotifications {
    return [_queuedNotifications copy];
}

- (NSArray<WTYLocalNotification *> *)scheduledWTYLocalNotifications {
    return [_scheduledNotifications copy];
}

- (NSInteger)queuedCount {
    return _queuedNotifications.count;
}

- (NSInteger)scheduledCount {
    return _scheduledNotifications.count;
}

- (NSInteger)count {
    return self.queuedCount + self.scheduledCount;
}


#pragma mark - Debug

- (void)debugPrintAllNotifications {
#ifdef DEBUG
    if (self.count == 0) {
        NSLog(@"There is no notification tracked by WTYLocalNotificationScheduler!");
        return;
    }
    if (self.scheduledCount) {
        NSLog(@"======= Scheduled Notification =======");
        for (WTYLocalNotification *n in _scheduledNotifications) {
            [n debugPrint];
        }
    }
    if (self.queuedCount) {
        NSLog(@"======= Queued Notification =======");
        for (WTYLocalNotification *n in _queuedNotifications) {
            [n debugPrint];
        }
    }
#endif
}

- (void)debugPrintAllNotificationsBrief {
#ifdef DEBUG
    if (self.count == 0) {
        NSLog(@"There is no notification tracked by WTYLocalNotificationScheduler!");
        return;
    }
    if (self.scheduledCount) {
        NSLog(@"======= Scheduled Notification =======");
        for (WTYLocalNotification *n in _scheduledNotifications) {
            [n debugPrintBrief];
        }
    }
    if (self.queuedCount) {
        NSLog(@"======= Queued Notification =======");
        for (WTYLocalNotification *n in _queuedNotifications) {
            [n debugPrintBrief];
        }
    }
#endif
}

#pragma mark - UIApplication Notification

- (void)handleUIApplicationNotification:(NSNotification *)notification {
    if ([notification.name isEqualToString:UIApplicationDidFinishLaunchingNotification]) {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"TYLNSchedulerInitiatedOnce"]) {
            // When user delete the app and reinstall it, the previous unfired scheduled notifications will still be there. So just cancel all scheduled notification.
            [self cancelAllNotifications];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"TYLNSchedulerInitiatedOnce"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    } else if ([notification.name isEqualToString:UIApplicationDidBecomeActiveNotification]) {
        [self scheduleNotificationFromQueue];
    } else if ([notification.name isEqualToString:UIApplicationWillResignActiveNotification]) {
        [self saveQueue];
    }
}

#pragma mark - Method Swizzling

+ (void)initialize {
    Class *classes = NULL;
    int numOfClasses = objc_getClassList(NULL, 0);
    
    if (numOfClasses > 0 )
    {
        classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numOfClasses);
        numOfClasses = objc_getClassList(classes, numOfClasses);
        for (int i = 0; i < numOfClasses; i++) {
            if (class_conformsToProtocol(classes[i], @protocol(UIApplicationDelegate))) {
                IMP swizzledImp;
                Method method;
                SEL selector;
                char *types;
                
                swizzledImp = (IMP)tyln_swizzledImpOfDidReceiveLocalNotification;
                selector = @selector(application:didReceiveLocalNotification:);
                method = class_getInstanceMethod(classes[i], selector);
                if (method) {
                    tyln_orignalImpOfDidReceiveLocalNotification = method_setImplementation(method, swizzledImp);
                } else {
                    tyln_orignalImpOfDidReceiveLocalNotification = nil;
                    types = protocol_getMethodDescription(@protocol(UIApplicationDelegate), selector, NO, YES).types;
                    class_addMethod(classes[i], selector, swizzledImp, types);
                }
                
                
                swizzledImp = (IMP)tyln_swizzledImpOfHandleActionWithIdentifierForLocalNotification;
                selector = @selector(application:handleActionWithIdentifier:forLocalNotification:completionHandler:);
                method = class_getInstanceMethod(classes[i], selector);
                if (method) {
                    tyln_orignalImpOfHandleActionWithIdentifierForLocalNotification = method_setImplementation(method, swizzledImp);
                } else {
                    tyln_orignalImpOfHandleActionWithIdentifierForLocalNotification = nil;
                    types = protocol_getMethodDescription(@protocol(UIApplicationDelegate), selector, NO, YES).types;
                    class_addMethod(classes[i], selector, swizzledImp, types);
                }
                
                
                swizzledImp = (IMP)tyln_swizzledImpOfHandleActionWithIdentifierForLocalNotificationWithResponseInfo;
                selector = @selector(application:handleActionWithIdentifier:forLocalNotification:withResponseInfo:completionHandler:);
                method = class_getInstanceMethod(classes[i], selector);
                if (method) {
                    tyln_orignalImpOfHandleActionWithIdentifierForLocalNotificationWithResponseInfo = method_setImplementation(method, swizzledImp);
                } else {
                    tyln_orignalImpOfHandleActionWithIdentifierForLocalNotificationWithResponseInfo = nil;
                    types = protocol_getMethodDescription(@protocol(UIApplicationDelegate), selector, NO, YES).types;
                    class_addMethod(classes[i], selector, swizzledImp, types);
                }
                break;
            }
        }
        free(classes);
    }
}

static IMP tyln_orignalImpOfDidReceiveLocalNotification;
void tyln_swizzledImpOfDidReceiveLocalNotification(id self, SEL _cmd, UIApplication *application, UILocalNotification *notification) {
    
    [[WTYLocalNotificationScheduler sharedScheduler] scheduleNotificationFromQueue];
    if (tyln_orignalImpOfDidReceiveLocalNotification) {
        ((void(*)(id,SEL,UIApplication*,UILocalNotification*))tyln_orignalImpOfDidReceiveLocalNotification)(self,_cmd,application, notification);
    }
}

static IMP tyln_orignalImpOfHandleActionWithIdentifierForLocalNotification;
void tyln_swizzledImpOfHandleActionWithIdentifierForLocalNotification(id self, SEL _cmd, UIApplication *application, NSString *identifier, UILocalNotification *notification, void (^completionHandler)(void)) {
    
    [[WTYLocalNotificationScheduler sharedScheduler] scheduleNotificationFromQueue];
    if (tyln_orignalImpOfHandleActionWithIdentifierForLocalNotification) {
        ((void(*)(id,SEL,UIApplication*,NSString*,UILocalNotification*,void(^)(void)))tyln_orignalImpOfHandleActionWithIdentifierForLocalNotification)(self, _cmd, application, identifier, notification, completionHandler);
    }
}

static IMP tyln_orignalImpOfHandleActionWithIdentifierForLocalNotificationWithResponseInfo;
void tyln_swizzledImpOfHandleActionWithIdentifierForLocalNotificationWithResponseInfo(id self, SEL _cmd,  UIApplication *application, NSString *identifier, UILocalNotification *notification, NSDictionary *responseInfo, void (^completionHandler)(void)) {
    
    [[WTYLocalNotificationScheduler sharedScheduler] scheduleNotificationFromQueue];
    if (tyln_orignalImpOfHandleActionWithIdentifierForLocalNotificationWithResponseInfo) {
        ((void(*)(id,SEL,UIApplication*,NSString*,UILocalNotification*,NSDictionary*,void (^)(void)))tyln_orignalImpOfHandleActionWithIdentifierForLocalNotificationWithResponseInfo)(self,_cmd,application,identifier,notification,responseInfo,completionHandler);
    }
}
@end
