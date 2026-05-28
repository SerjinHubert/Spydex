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
      settings: initSettings,
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

    // 1. Pre-Market Prep (8:30 AM Mon-fri)
    await _scheduleWeekday(
      baseId: 10,
      title: 'Get Ready for the Bell 🔔',
      body: 'Review your past mistakes in Spydex before the market opens. Stick to your rules!',
      hour: 8,
      minute: 30,
    );

    // 2. Market Closed/Journal Time (4:30 PM Mon-fri)
    await _scheduleWeekday(
      baseId: 20,
      title: 'Market is Closed! 📉📈',
      body: 'Time to log today\'s trades and taxes. Keep your Spydex journal updated.',
      hour: 16,
      minute: 30,
    );

    // 3. Evening Discipline Check (8:00 PM Mon-fri)
    await _scheduleWeekday(
      baseId: 30,
      title: 'Focus. Discipline. Trade. 🦅',
      body: 'Did you review today\'s setups? Log your final P&L and mistakes.',
      hour: 20,
      minute: 0,
    );

    // 4. Weekly Recap (Friday 5:00 PM)
    await _scheduleWeekly(
      id: 40,
      title: 'Weekly Recap Time 📊',
      body: 'The trading week is over. Check your Win Rate and average P&L on the Dashboard!',
      day: DateTime.friday,
      hour: 17,
      minute: 0,
    );

    // 5. Mid-Day Slump Warning (12:30 PM Mon-fri)
    await _scheduleWeekday(
      baseId: 50,
      title: 'Mid-Day Check-in 🕒',
      body: 'Volume is slowing down. Don\'t force trades out of boredom. Wait for your A+ setups!',
      hour: 12,
      minute: 30,
    );

    // 6. Morning Volatility Check (10:30 AM Mon-fri)
    await _scheduleWeekday(
      baseId: 60,
      title: 'Stay Calm & Composed 🧘',
      body: 'The morning rush is over. Protect your capital and absolutely no revenge trading.',
      hour: 10,
      minute: 30,
    );

    // 7. Sunday Night Prep (Sunday at 7:00 PM)
    await _scheduleWeekly(
      id: 70,
      title: 'Prepare for the Week 📅',
      body: 'The markets open tomorrow! Review your weekend charts, check the news calendar, and plan your trades.',
      day: DateTime.sunday,
      hour: 19,
      minute: 0,
    );

    // 8. Monthly Performance Review (1st of Every Month)
    await _scheduleMonthly(
      id: 80,
      title: 'New Month, New Goals 📈',
      body: 'Your monthly P&L is ready. Review your win rate from last month and refine your strategy.',
      dayOfMonth: 1,
      hour: 9,
      minute: 0,
    );

    // 9. Tax & Brokerage Reminder (Saturday at 10:00 AM)
    await _scheduleWeekly(
      id: 90,
      title: 'Audit Your Fees 📝',
      body: 'Take 5 minutes to ensure all your taxes and brokerage fees are logged for accurate Net P&L.',
      day: DateTime.saturday,
      hour: 10,
      minute: 0,
    );

    // 10. Pre-Weekend Disconnect (Friday at 8:00 PM)
    await _scheduleWeekly(
      id: 100,
      title: 'Disconnect & Recharge 🔋',
      body: 'The market is closed for the weekend. Close the charts, rest your mind, and enjoy your time off.',
      day: DateTime.friday,
      hour: 20,
      minute: 0,
    );
  }

  static Future<void> _scheduleWeekday({required int baseId, required String title, required String body, required int hour, required int minute}) async {
    // Schedule for Monday to Friday (1 to 5)
    for (int i = 1; i <= 5; i++) {
      await _scheduleWeekly(
        id: baseId * 10 + i,
        title: title,
        body: body,
        day: i,
        hour: hour,
        minute: minute,
      );
    }
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> _scheduleMonthly({required int id, required String title, required String body, required int dayOfMonth, required int hour, required int minute}) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfMonthDayTime(dayOfMonth, hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'spydex_monthly',
          'Monthly Review',
          channelDescription: 'Monthly trading review',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
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

  static tz.TZDateTime _nextInstanceOfMonthDayTime(int dayOfMonth, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, dayOfMonth, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month + 1, dayOfMonth, hour, minute);
    }
    return scheduledDate;
  }
}
