# WTYLocalNotificationScheduler

[![Version](https://img.shields.io/cocoapods/v/WTYLocalNotificationScheduler.svg?style=flat)](http://cocoapods.org/pods/WTYLocalNotificationScheduler)
[![License](https://img.shields.io/cocoapods/l/WTYLocalNotificationScheduler.svg?style=flat)](http://cocoapods.org/pods/WTYLocalNotificationScheduler)
[![Platform](https://img.shields.io/cocoapods/p/WTYLocalNotificationScheduler.svg?style=flat)](http://cocoapods.org/pods/WTYLocalNotificationScheduler)

## About

WTYLocalNotificationScheduler is used for schedule UILocalNotification with custom repeat interval and make it easy to change the notification content when it repeats.

It should be used for iOS 8 / 9. For iOS 10, please use Apple's new UNNotification framework.

## Requirements

* iOS 8 / 9
* Xcode 7 +

## Installation

WTYLocalNotificationScheduler is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "WTYLocalNotificationScheduler"
```

## HowTo

First import this header file

```objc
#import "WTYLocalNotificationScheduler.h"
```

Then create an instance of `WTYLocalNotification` and set its properties as you need. Most of the `UILocalNotification` properties can be used in `WTYLocalNotification` except for repeatInterval, region and regionTriggersOnce. 

```objc
WTYLocalNotification *notification = [[WTYLocalNotification alloc] init];
notification.alertBody = @"Notification Body";
notification.fireDate = [NSDate dateWithTimeIntervalSinceNow:3600];
notification.timeZone = [NSTimeZone systemTimeZone];
notification.repeatIntervalValue = 1;
notification.repeatIntervalUnit = WTYLNRepeatIntervalUnitDay;
```

And you should use repeatIntervalValue and repeatIntervalUnit instead of repeatInterval to let the notification repeat at custom interval. The valid units are shown below.

```objc
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
```
Please note that in iOS 8 / 9 UILocalNotification system can only store the nearest 64 notifications. 

WTYLocalNotificationScheduler maintain a notification queue. Once you schedule a notification with custom repeat interval, it will create several new notifications with repeated fire date based on your notification's properties and try to schedule it if it is the nearest 64 notifications. Then store the notification with next fire date in the notification queue. 

So if the nearest 64 notifications are all fired. User won't get further notification until the app open. But once the app is open again, the scheduler will try to schedule as much as possible notifications from the notification queue. You should select your repeat interval wisely.

After setup your instance of `WTYLocalNotification`, you can schedule it with the method below and get the notification ID.

```objc
NSString *notificationID = [[WTYLocalNotificationScheduler sharedScheduler] scheduleNotification:notification];
```

If you want to alter the content of a notification with custom repeat interval. You can provie a block for scheduler's property in your AppDelegate's method `application:didFinishLaunchingWithOptions:`.

```objc
@property (nonatomic, copy, nullable) void (^notificationUpdateBlock)(WTYLocalNotification *notification);
```

Please do not modify fireDate, timeZone, repeatIntervalValue, repeatIntervalUnit and repeatCalendar, otherwise the scheduler may not work as expected.

You can cancel a specific notification with its notification ID or cancel all notifications.

```objc
[[WTYLocalNotificationScheduler sharedScheduler] cancelNotificationWithIdentifier:notificationID];

[[WTYLocalNotificationScheduler sharedScheduler] cancelAllNotifications];
```

## Author

Tianyu Wang, wty21cn@gmail.com

## License

WTYLocalNotificationScheduler is available under the MIT license. See the LICENSE file for more info.
