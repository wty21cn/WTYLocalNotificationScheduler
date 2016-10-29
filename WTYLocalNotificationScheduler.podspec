Pod::Spec.new do |s|
  s.name             = 'WTYLocalNotificationScheduler'
  s.version          = '0.1.0'
  s.summary          = 'WTYLocalNotificationScheduler is used for iOS 8/9 to schedule UILocalNotification with custom repeat interval.'
  s.description      = <<-DESC
WTYLocalNotificationScheduler is used for iOS 8/9 to schedule UILocalNotification with custom repeat interval and make it easy to change the notification content when it repeats.
                       DESC

  s.homepage         = 'https://github.com/wty21cn/WTYLocalNotificationScheduler'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Tianyu Wang' => 'wty21cn@gmail.com' }
  s.source           = { :git => 'https://github.com/wty21cn/WTYLocalNotificationScheduler.git', :tag => s.version.to_s }
  s.social_media_url = 'http://wty.im'

  s.ios.deployment_target = '8.0'

  s.source_files = 'WTYLocalNotificationScheduler/Classes/**/*'

end
