//
//  WTYLocalNotification.m
//  WTYLocalNotificationScheduler
//
//  Created by Rain on 16/8/10.
//  Copyright © 2016 Rain Wang. All rights reserved.
//

#import "WTYLocalNotification.h"
#import "WTYLocalNotification_Internal.h"

static NSString * const kRepeatIntervalUnitKey = @"RepeatIntervalUnit";
static NSString * const kRepeatIntervalValueKey = @"RepeatIntervalValue";
static NSString * const kNotificationIDKey = @"NotificationID";
static NSString * const kUILocalNotificationKey = @"UILocalNotification";
static const NSInteger kMinimumRepeatIntervalValue = 1;
static const WTYLNRepeatIntervalUnit kDefaultRepeatIntervalUnit = WTYLNRepeatIntervalUnitNone;


@implementation WTYLocalNotification

#pragma mark

- (BOOL)prepareToBeScheduled {
    
    BOOL shouldFireNow = [self updateFireDate];
    
    // Must call updateFireDate before generate notificationID,
    // because updateFireDate will check if notificationID is valid or not to take different action.
    if (!self.notificationID) {
        self.notificationID = [[NSUUID UUID] UUIDString];
    }

    NSMutableDictionary *userInfo = [self.notification.userInfo mutableCopy] ?:[NSMutableDictionary dictionary];
    [userInfo addEntriesFromDictionary:@{kNotificationIDKey     : _notificationID,
                                         kRepeatIntervalValueKey: @(_repeatIntervalValue),
                                         kRepeatIntervalUnitKey : @(_repeatIntervalUnit)}];
    self.notification.userInfo = [userInfo copy];
    return shouldFireNow;
}

/**
 *  Update the fire date takeing repeat interval into consideration.
 *
 *  @return If the notification is a new notification and its fireDate is in the past, this method will return true, indicating that the notification should be fire immediately. If it is not a new notification and the previous firDate is in the past, this method will calculate the next notification fire date which will be in the future, considering the repeat interval, and this method will return false.
 */
- (BOOL)updateFireDate {
    
    NSDate *now = [NSDate date];
    if (self.timeZone) {
        // The date specified in fireDate is interpreted according to the value of this timeZone property
        // Because when timeZone is set, the fireDate will be a relative Date.
        // So in order to compare with now, we need to adjust now with the defaultTimezone, and adjust fireDate with timeZone
        // now + defaultTimeZone ? fireDate + self.timeZone => now + defaultTimeZone - self.timeZone ? fireDate
        now = [now dateByAddingTimeInterval:[[NSTimeZone defaultTimeZone] secondsFromGMT]];
        now = [now dateByAddingTimeInterval:-[self.timeZone secondsFromGMT]];
    }
    if ([self.fireDate compare:now] != NSOrderedDescending) {
        // fireDate is in the past
        if (!self.notificationID || self.repeatIntervalUnit == WTYLNRepeatIntervalUnitNone) {
            // New Notification or No repeat interval
            self.fireDate = now;
            return YES;
        } else {
            
            NSCalendar *calendar = self.notification.repeatCalendar ?:[NSCalendar currentCalendar];
            NSDateComponents *interval = [self repeatIntervalDateComponents];
            NSDate *fireDate = self.fireDate;
            while ([fireDate compare:now] == NSOrderedAscending) {
                fireDate = [calendar dateByAddingComponents:interval toDate:fireDate options:0];
            }
            self.fireDate = fireDate;
            return NO;
        }
    }
    return NO;
}

- (NSComparisonResult)compare:(WTYLocalNotification *)notification {
    if (self == notification) {
        return NSOrderedSame;
    }
    NSComparisonResult fireDateComparisonResult = [[self.fireDate dateByAddingTimeInterval:[self.timeZone secondsFromGMT]] compare:[notification.fireDate dateByAddingTimeInterval:[notification.timeZone secondsFromGMT]]];
    if (fireDateComparisonResult != NSOrderedSame) {
        return fireDateComparisonResult;
    } else {
        return [self.notificationID caseInsensitiveCompare:notification.notificationID];
    }
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if ([self class] != [object class]) return NO;
    
    if ([self.notificationID isEqualToString:[object notificationID]]) {
        return YES;
    }
    return NO;
}

- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%@", self.notificationID] hash];
}

#pragma mark - Init

- (instancetype)init
{
    self = [super init];
    if (self) {
        _notification = [[UILocalNotification alloc] init];
        
        _notificationID = nil;
        _repeatIntervalValue = kMinimumRepeatIntervalValue;
        _repeatIntervalUnit = kDefaultRepeatIntervalUnit;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    
    WTYLocalNotification *copy = [[WTYLocalNotification alloc] initWithUILocalNotification:self.notification syncStatus:[self isSynchronized] notificationID:self.notificationID repeatIntervalValue:self.repeatIntervalValue repeatIntervalUnit:self.repeatIntervalUnit];
    return copy;
    
}

/// This method is called by initWithCoder: to initialize TYLocalNotification from data stored on disk.
- (instancetype)initWithUILocalNotification:(UILocalNotification *)notification syncStatus:(BOOL)syncStatus notificationID:(NSString *)notificationID repeatIntervalValue:(NSInteger)repeatIntervalValue repeatIntervalUnit:(WTYLNRepeatIntervalUnit)repeatIntervalUnit {
    self = [super init];
    if (self) {
        _notification = [notification copy];
        _synchronized = syncStatus;
        _notificationID = [notificationID copy];
        _repeatIntervalUnit = repeatIntervalUnit;
        _repeatIntervalValue = repeatIntervalValue;
        
    }
    return self;
}

+ (instancetype)notificationWithUILocalNotification:(UILocalNotification *)notification {
    NSString *notificationID = notification.userInfo[kNotificationIDKey];
    if (notificationID) {
        NSUInteger repeatIntervalUnit = [notification.userInfo[kRepeatIntervalUnitKey] unsignedIntegerValue];
        WTYLNRepeatIntervalUnit repeatIntervalValue = [notification.userInfo[kRepeatIntervalValueKey] unsignedIntegerValue];
        return [[WTYLocalNotification alloc] initWithUILocalNotification:notification
                                                             syncStatus:YES
                                                         notificationID:notificationID
                                                    repeatIntervalValue:repeatIntervalValue
                                                     repeatIntervalUnit:repeatIntervalUnit];
    } else {
        return nil;
    }
}

+ (instancetype)notificationWithTYLocalNotification:(WTYLocalNotification *)notification copyID:(BOOL)flag {
    WTYLocalNotification *new = [[WTYLocalNotification alloc] init];
    new.notification = [notification.notification copy];
    new.synchronized = [notification isSynchronized];
    new.repeatIntervalValue = notification.repeatIntervalValue;
    new.repeatIntervalUnit = notification.repeatIntervalUnit;
    if (flag) {
        new.notificationID  = notification.notificationID;
    } else {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:new.userInfo];
        [userInfo removeObjectForKey:kNotificationIDKey];
        new.userInfo = userInfo;
    }
    return new;
}

- (instancetype)notificationOfNextFireDate {
    
    if (self.repeatIntervalUnit == WTYLNRepeatIntervalUnitNone) {
        return nil;
    }
    
    WTYLocalNotification *next = [WTYLocalNotification notificationWithTYLocalNotification:self copyID:YES];
    NSCalendar *calendar = self.notification.repeatCalendar ?:[NSCalendar currentCalendar];
    NSDateComponents *interval = [self repeatIntervalDateComponents];
    next.fireDate = [calendar dateByAddingComponents:interval toDate:self.fireDate options:0];
    return next;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    UILocalNotification *notification = [aDecoder decodeObjectForKey:kUILocalNotificationKey];
    NSString *notificationID = [aDecoder decodeObjectForKey:kNotificationIDKey];
    NSUInteger repeatIntervalValue = [[aDecoder decodeObjectForKey:kRepeatIntervalValueKey] unsignedIntegerValue];
    WTYLNRepeatIntervalUnit repeateIntervalUnit = [[aDecoder decodeObjectForKey:kRepeatIntervalUnitKey] unsignedIntegerValue];
    
    return [self initWithUILocalNotification:notification syncStatus:NO notificationID:notificationID repeatIntervalValue:repeatIntervalValue repeatIntervalUnit:repeateIntervalUnit];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_notification forKey:kUILocalNotificationKey];
    [aCoder encodeObject:_notificationID forKey:kNotificationIDKey];
    [aCoder encodeObject:@(_repeatIntervalValue) forKey:kRepeatIntervalValueKey];
    [aCoder encodeObject:@(_repeatIntervalUnit) forKey:kRepeatIntervalUnitKey];
}

#pragma mark - Helper

/**
 *  Get the date components represent the receiver's repeat interval.
 *
 *  @return The date components represent the receiver's repeat interval
 */
- (NSDateComponents *)repeatIntervalDateComponents {
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    switch (self.repeatIntervalUnit) {
        case WTYLNRepeatIntervalUnitMinute:
            interval.minute = self.repeatIntervalValue;
            break;
        case WTYLNRepeatIntervalUnitHour:
            interval.hour = self.repeatIntervalValue;
            break;
        case WTYLNRepeatIntervalUnitDay:
            interval.day = self.repeatIntervalValue;
            break;
        case WTYLNRepeatIntervalUnitWeekOfYear:
            interval.weekOfYear = self.repeatIntervalValue;
            break;
        case WTYLNRepeatIntervalUnitMonth:
            interval.month = self.repeatIntervalValue;
            break;
        case WTYLNRepeatIntervalUnitYear:
            interval.year = self.repeatIntervalValue;
            break;
        case WTYLNRepeatIntervalUnitNone:
            break;
    }
    return interval;
}

#pragma mark - Debug

- (void)debugPrint {
#ifdef DEBUG
    NSLog(@"---------------------------------------------");
    NSLog(@"NotificationID: %@", self.notificationID);
    NSLog(@"FireDate: %@, TimeZone: %@", self.fireDate, self.timeZone);
    NSLog(@"RealFireDate: %@", [self.fireDate dateByAddingTimeInterval:[self.timeZone secondsFromGMT]]);
    NSLog(@"AlertTitle: %@", self.alertTitle);
    NSLog(@"AlertBody: %@", self.alertBody);
    NSString *unit = nil;
    switch (self.repeatIntervalUnit) {
        case WTYLNRepeatIntervalUnitNone:
            unit = @"Don't repeat!";
            break;
        case WTYLNRepeatIntervalUnitMinute:
            unit = @"Minute";
            break;
        case WTYLNRepeatIntervalUnitHour:
            unit = @"Hour";
            break;
        case WTYLNRepeatIntervalUnitDay:
            unit = @"Day";
            break;
        case WTYLNRepeatIntervalUnitWeekOfYear:
            unit = @"Week";
            break;
        case WTYLNRepeatIntervalUnitMonth:
            unit = @"Month";
            break;
        case WTYLNRepeatIntervalUnitYear:
            unit = @"Year";
            break;
    }
    NSLog(@"RepeatVlue: %@, RepeatUnit: %@", @(self.repeatIntervalValue), unit);
    NSLog(@"UserInfo: %@", self.userInfo);
    NSLog(@"---------------------------------------------");
#endif
}

- (void)debugPrintBrief {
#ifdef DEBUG
    NSLog(@"---------------------------------------------");
    NSLog(@"RealFireDate: %@", [self.fireDate dateByAddingTimeInterval:[self.timeZone secondsFromGMT]]);
    NSString *unit = nil;
    switch (self.repeatIntervalUnit) {
        case WTYLNRepeatIntervalUnitNone:
            unit = @"Don't repeat!";
            break;
        case WTYLNRepeatIntervalUnitMinute:
            unit = @"Minute";
            break;
        case WTYLNRepeatIntervalUnitHour:
            unit = @"Hour";
            break;
        case WTYLNRepeatIntervalUnitDay:
            unit = @"Day";
            break;
        case WTYLNRepeatIntervalUnitWeekOfYear:
            unit = @"Week";
            break;
        case WTYLNRepeatIntervalUnitMonth:
            unit = @"Month";
            break;
        case WTYLNRepeatIntervalUnitYear:
            unit = @"Year";
            break;
    }
    NSLog(@"AlertBody: %@, RepeatVlue: %@, RepeatUnit: %@", self.alertBody, @(self.repeatIntervalValue), unit);
    NSLog(@"NotificationID: %@",self.notificationID);
#endif
}


#pragma mark - Custom Accessor

- (void)setRepeatIntervalValue:(NSUInteger)repeatIntervalValue {
    if (repeatIntervalValue < kMinimumRepeatIntervalValue) {
        repeatIntervalValue = kMinimumRepeatIntervalValue;
    }
    _repeatIntervalValue = repeatIntervalValue;
}

#pragma mark - UILocalNotification Properties

@dynamic fireDate, timeZone, repeatCalendar, alertBody, alertAction, hasAction;
@dynamic alertLaunchImage, category, applicationIconBadgeNumber, soundName, userInfo;

- (NSString *)alertTitle {
    if ([_notification respondsToSelector:@selector(alertTitle)]) {
        return _notification.alertTitle;
    } else {
        return nil;
    }
}

- (void)setAlertTitle:(NSString *)alertTitle {
    if ([_notification respondsToSelector:@selector(setAlertTitle:)]) {
        _notification.alertTitle = alertTitle;
    }
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return _notification;
}
@end
