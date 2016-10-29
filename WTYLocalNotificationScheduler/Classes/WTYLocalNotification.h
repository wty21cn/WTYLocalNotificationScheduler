//
//  WTYLocalNotification.h
//  WTYLocalNotificationScheduler
//
//  Created by Rain on 16/8/10.
//  Copyright © 2016 Rain Wang. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 *  Specify calendrical units used by TYLocalNotificationScheulder combined with the property repeatIntervalValue as notification repeat interval unit. 
 *  The unit cannot be combined, specifies only one at a time.
 */
typedef NS_ENUM(NSUInteger, WTYLNRepeatIntervalUnit) {
    
    /// This means no repeat interval.
    WTYLNRepeatIntervalUnitNone = 0,
    /// Specifies the minute unit.
    WTYLNRepeatIntervalUnitMinute = kCFCalendarUnitMinute,
    /// Specifies the hour unit.
    WTYLNRepeatIntervalUnitHour = kCFCalendarUnitHour,
    /// Specifies the day unit.
    WTYLNRepeatIntervalUnitDay = kCFCalendarUnitDay,
    /// Specifies the week unit.
    WTYLNRepeatIntervalUnitWeekOfYear = kCFCalendarUnitWeekOfYear,
    /// Specifies the month unit.
    WTYLNRepeatIntervalUnitMonth = kCFCalendarUnitMonth,
    /// Specifies the year unit.
    WTYLNRepeatIntervalUnitYear = kCFCalendarUnitYear
    
};

#pragma mark - WTYLocalNotification

@interface WTYLocalNotification : NSObject <NSCoding, NSCopying>

#pragma mark - Properties
///-------------------------
/// @name UILocalNotification Properties.
///-------------------------

/// The date and time when the system should deliver the notification.
@property (nonatomic, copy) NSDate *fireDate;
/// The time zone of the notification’s fire date.
@property (nonatomic, copy) NSTimeZone *timeZone;
/// The calendar the system should refer to when it reschedules a repeating notification.
@property (nonatomic, copy) NSCalendar *repeatCalendar;
/// A short description of the reason for the alert.
@property (nonatomic, copy) NSString *alertTitle NS_AVAILABLE_IOS(8_2);
/// The message displayed in the notification alert.
@property (nonatomic, copy) NSString *alertBody;
/// The title of the action button or slider.
@property (nonatomic, copy) NSString *alertAction;
/// A Boolean value that controls whether the notification shows or hides the alert action.
@property (nonatomic, assign) BOOL hasAction;
/// Identifies the image used as the launch image when the user taps (or slides) the action button (or slider).
@property (nonatomic, copy) NSString *alertLaunchImage;
/// The name of a group of actions to display in the alert.
@property (nonatomic, copy) NSString *category;
/// The number to display as the app’s icon badge.
@property (nonatomic, assign) NSInteger applicationIconBadgeNumber;
/// The name of the file containing the sound to play when an alert is displayed.
@property (nonatomic, copy) NSString *soundName;
/// A dictionary for passing custom information to the notified app.
@property (nonatomic, copy) NSDictionary *userInfo;

///-------------------------
/// @name TYLocalNotification Properties.
///-------------------------

/**
 *  This property indicate whether this TYLocalNotification is scheduled and synchronized to iOS UILocalNotification system
 */
@property (nonatomic, assign, readonly, getter=isSynchronized) BOOL synchronized;

/**
 *  TYLocalNotificaion is backed by UILocalNotification. Access this property will get a copy of the backing store.
 */
@property (nonatomic, copy, readonly) UILocalNotification *notification;

/**
 *  Default is TYLNRepeatIntervalUnitNone, which means that the system fires the notification once and then discards it.
 */
@property (nonatomic, assign) WTYLNRepeatIntervalUnit repeatIntervalUnit;

/**
 *  Default value is 1. You can modify this value, but it cannot be less than 1, otherwise the default value 1 will be
 used.
 *
 *  When you set repeatIntervalUnit other than TYLNRpeatIntervalUnitNone, it means TYLocalNotificaionScheduler will use this value combined with repeatIntervalUnit to repeat the notification in custom repeatInterval.
 */
@property (nonatomic, assign) NSUInteger repeatIntervalValue;

/**
 *  This is the unique identifier for the TYLocalNotification instance. This property is valid only after scheduled by TYLocalNotificationScheduler, otherwise it is nil.
 */
@property (nonatomic, copy, readonly) NSString *notificationID;

#pragma mark - Methods

/**
 *  Initiallize a new TYLocalNotification.
 *
 *  @return An instance of TYLocalNotification if successfully initialized, otherwise return nil
 */
- (instancetype)init;

/**
 *  Build TYLocalNotification from UILocalNotification which is previously created by TYLocalNotification
 *
 *  @param notification UILocalNotification
 *
 *  @return TYLocalNotificaion if the input UILocalNotification is previously created by TYLocalNotification, otherwise nil
 */
+ (instancetype)notificationWithUILocalNotification:(UILocalNotification *)notification;

/**
 *  Build a new TYLocalNotification from input TYLocalNotification, all properties will be copied to the new instance instead of notificatoinID.
 *
 *  @param notification A TYLocalNotification.
 *  @param flag If YES, the notificationID will be copied as well.
 *
 *  @return New instance of TYLocalNotification.
 */
+ (instancetype)notificationWithTYLocalNotification:(WTYLocalNotification *)notification copyID:(BOOL)flag;

/**
 *  This method return a new instance of TYLocalNotification if the receiver's repeatIntervalUnit is not TYLNRepeatIntervalUnitNone.
 *
 *  All the propertis of the new instance are the same with the receiver's, except for fireDate, which is calculated using the receiver's fireDate and repeatInterval.
 *
 *  @return A new instance of TYLocalNofication of next fire date, if the receiver's repeatIntervalUnit is TYLNRepeatIntervalUnitNone, return nil.
 */
- (instancetype)notificationOfNextFireDate;

/**
 *  Compare receiver's fireDate and notificationID against input notification's
 *
 *  @param notification The notification to be compared against the receiver
 *
 *  @return Returns an NSComparisonResult. NSOrderedAscending the receiver's fireDate precedes the notifications's, and NSOrderedDescending if the receiver's fireDate follows notification's. If the receiver and notification has the same fireDate, return the caseInsensitiveCompare result of the receiver and notification.
 */
- (NSComparisonResult)compare:(WTYLocalNotification *)notification;

/**
 *  Determine whether the input object is a TYLocalNotification and it's notificationID is equal to the receiver's notificationID
 *
 *  @param object Input object
 *
 *  @return When the input object is a TYLocalNotification and it's notificationID is equal to the receiver's notificationID, return YES, otherwise return NO
 */
- (BOOL)isEqual:(id)object;

/**
 *  If two TYLocalNotification objects are equal (as determined by the isEqual: method), they must have the same hash value. This property fulfills this requirement.
 *
 *  @return TYLocalNotification's hash value
 */
- (NSUInteger)hash;

/**
 *  This method is for debug purpose only. It will print out the detail TYLocalNotification info of the the the receiver.
 */
- (void)debugPrint;
- (void)debugPrintBrief;

@end
