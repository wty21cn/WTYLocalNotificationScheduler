//
//  WTYLocalNotification_Internal.h
//  WTYLocalNotificationScheduler
//
//  Created by Rain on 16/8/10.
//  Copyright © 2016 Rain Wang. All rights reserved.
//

#import "WTYLocalNotification.h"

@interface WTYLocalNotification ()

@property (nonatomic, copy, readwrite) UILocalNotification *notification;
@property (nonatomic, copy, readwrite) NSString *notificationID;
@property (nonatomic, assign, readwrite, getter=isSynchronized) BOOL synchronized;

/**
 *  This method should and only be called by WTYLocalNotificationScheduler before schedule the notification. It will update notificationID and userInfo to store WTYLocalNotification info, and adjust the fireDate.
 *
 *  This method will call updateFireDate, details please see docs for updateFireDate.
 *
 *  @return If the notification is a new notification and its fireDate is in the past, this method will return true, indicating that the notification should be fire immediately. If it is not a new notification and the previous date is in the past, this method return false.
 *
 *  @see updateFireDate
 */
- (BOOL)prepareToBeScheduled;

@end
