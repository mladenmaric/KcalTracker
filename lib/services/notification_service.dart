import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static int _nextId = 0;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS    = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: iOS),
    );

    // Request Android 13+ runtime permission.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'trainer_feedback',
      'Trainer Feedback',
      channelDescription: 'Notifications when your trainer leaves meal comments',
      importance: Importance.high,
      priority:   Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS:     DarwinNotificationDetails(),
    );

    await _plugin.show(_nextId++, title, body, details);
  }
}
