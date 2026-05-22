import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize timezone data
    tz.initializeTimeZones();
    
    // Initialize for Android (using default flutter icon)
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Initialize for iOS
    const DarwinInitializationSettings initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );
    
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap if needed
      },
    );

    // Request Android permissions (iOS is requested during initSettingsIOS)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _isInitialized = true;

    // Schedule all automated notifications
    await _scheduleAllNotifications();
  }

  static Future<void> _scheduleAllNotifications() async {
    // Cancel any existing schedules to avoid duplicates
    await _notificationsPlugin.cancelAll();

    // Option 1: Post-Market Journal (4:30 PM Daily)
    await _scheduleDaily(
      id: 1,
      title: 'Market is Closed! 📉📈',
      body: 'Time to log today\'s trades and taxes. Keep your Spydex journal updated.',
      hour: 16,
      minute: 30,
    );

    // Option 2: Evening Discipline Check (8:00 PM Daily)
    await _scheduleDaily(
      id: 2,
      title: 'Focus. Discipline. Trade. 🦅',
      body: 'Did you review today\'s setups? Log your final P&L and mistakes.',
      hour: 20,
      minute: 0,
    );

    // Option 3: Pre-Market Prep (8:30 AM Daily)
    await _scheduleDaily(
      id: 3,
      title: 'Get Ready for the Bell 🔔',
      body: 'Review your past mistakes in Spydex before the market opens. Stick to your rules!',
      hour: 8,
      minute: 30,
    );

    // Option 4: Weekly Review (Friday at 5:00 PM)
    await _scheduleWeekly(
      id: 4,
      title: 'Weekly Recap Time 📊',
      body: 'The trading week is over. Check your Win Rate and average P&L on the Dashboard!',
      day: DateTime.friday,
      hour: 17,
      minute: 0,
    );
  }

  static Future<void> _scheduleDaily({required int id, required String title, required String body, required int hour, required int minute}) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'spydex_daily',
          'Daily Reminders',
          channelDescription: 'Daily trading reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // This makes it repeat daily
    );
  }

  static Future<void> _scheduleWeekly({required int id, required String title, required String body, required int day, required int hour, required int minute}) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfWeekdayTime(day, hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'spydex_weekly',
          'Weekly Review',
          channelDescription: 'Weekly trading review',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // This makes it repeat weekly
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static tz.TZDateTime _nextInstanceOfWeekdayTime(int day, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
