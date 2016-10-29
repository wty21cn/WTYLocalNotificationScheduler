//
//  WTYLocalNotificationScheduler.h
//  WTYLocalNotificationScheduler
//
//  Created by Rain on 16/8/11.
//  Copyright © 2016 Rain Wang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WTYLocalNotification.h"

@class WTYLocalNotification;

NS_ASSUME_NONNULL_BEGIN
@interface WTYLocalNotificationScheduler : NSObject


#pragma mark - Properties

/// The number of WTYLocalNotification which are already scheduled to iOS notification system.
@property (nonatomic, assign, readonly) NSInteger scheduledCount;
/// The number of notfications which are still in WTYLocalNotificationScheduler's pending queue
@property (nonatomic, assign, readonly) NSInteger queuedCount;
/// The total number of notifications which are tracked by WTYLocalNotificationScheduler
@property (nonatomic, assign, readonly) NSInteger count;
/// A copy of WTYLocalNotifications in the queue, or empty array if no WTYLocalNotification in the queue
@property (nonatomic, copy, readonly) NSArray<WTYLocalNotification *> *queuedWTYLocalNotifications;
/// A copy of WTYLocalNotifications which are already scheduled to iOS local notification system, or empty array if no WTYLocalNotification in iOS local notification system.
@property (nonatomic, copy, readonly) NSArray<WTYLocalNotification *> *scheduledWTYLocalNotifications;

/**
 *  This block will be called before schedule a notification to give user a chance to update the notification's properties. It is useful when dealing notification with repeat interval.
 *  If present, this block must be provide in AppDelegate's method application:didFinishLaunchingWithOptions:
 *  This block should only update properties of the notification which will not effect the fireDate.
 *  Do not modify fireDate, timeZone, repeatIntervalValue, repeatIntervalUnit, repeatCalendar, otherwise the scheduler may not work as expected.
 */
@property (nonatomic, copy, nullable) void (^notificationUpdateBlock)(WTYLocalNotification *notification);

#pragma mark - Methods

/**
 *  Please only use this mehtod to get the singleton of WTYLocalNotificationScheduler
 *
 *  @return WTYLocalNotificationScheduler singleton
 *
 *  Please only use this mehtod to get the singleton of WTYLocalNotificationScheduler
 */
+ (instancetype)sharedScheduler;

/**
 *  Schedule a WTYLocalNotification
 *  If the notification havs valid notificationID which means it is already scheduled with WTYLocalNotificationScheduler or already fired , this method do nothing and return nil.
 *
 *  The scheduler keeps a copy of this object so you may release the object once it is scheduled.
 *
 *  @param notification A WTYLocalNotification
 *
 *  @return The identifier of the notification if successfully scheduled, otherwise nil if failed.
 */
- (NSString *)scheduleNotification:(WTYLocalNotification *)notification;

- (NSArray<NSString *> *)scheduleNotifications:(NSArray<WTYLocalNotification *> *)notifications;

/**
 *  Please call this method at regular inteval, i.e. every time your app open or one of your notifications fired.
 *  So that WTYLocalNotificationScheduler can fill the iOS local notification system with the queued WTYLocalNotifications.
 *
 */
- (void)scheduleNotificationFromQueue;

/**
 *  Cancel a specific WTYLocalNotification
 *
 *  @param notification A WTYLocalNotification
 */
- (void)cancelNotification:(WTYLocalNotification *)notification;

/**
 *  Cancel a specific WTYLocalNotification which has the input identifier
 *
 *  @param identifier The identifier to be cancelled.
 */
- (void)cancelNotificationWithIdentifier:(NSString *)identifier;

/**
 *  Cancel all WTYLocalNotifications tracked by WTYLocalNotificationScheduler
 */
- (void)cancelAllNotifications;

/**
 *  Call this method whenever you need to save changes done to the queue
 *  and/or before terminating the app.
 */
- (void)saveQueue;

/**
 *  Get the WTYLocalNotification by identifier
 *
 *  @param identifier WTYLocalNotification identifier
 *
 *  @return WTYLocalNotification if identifier is tracked by WTYLocalNotificationScheduler, otherwise nil, if the notification has custom repeat interval, return the TYLocalNotification with nearest fireDate.
 */
- (WTYLocalNotification *)notificationWithIdentifier:(NSString *)identifier;

/**
 *  This method is for debug purpose only. It will print out all the notifications scheduled and queued by WTYLocalNotificationScheduler to the console.
 */
- (void)debugPrintAllNotifications;
- (void)debugPrintAllNotificationsBrief;

@end
NS_ASSUME_NONNULL_END
