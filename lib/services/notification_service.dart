import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'sos_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final SosService _sosService = SosService();
  final AuthService _authService = AuthService();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Register iOS categories for buttons
    final iosInit = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'sos_category',
          actions: [
            DarwinNotificationAction.plain(
              'trigger_sos',
              '🚨 QUICK SOS',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );
    
    await _notifications.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'trigger_sos') {
          _handleGlobalSosTrigger();
        }
      },
    );

    // CRITICAL: Request permissions for iOS
    await _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // CRITICAL: Request permissions for Android 13+
    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  Future<void> _handleGlobalSosTrigger() async {
    final UserModel? user = await _authService.getCurrentUser();
    if (user != null) {
      await _sosService.triggerSos(user.uid, user.name, user.guardianPhones);
    }
  }

  /// Shows a persistent, non-dismissible notification with an SOS button
  Future<void> showStickySosNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'sos_channel',
      'Emergency SOS',
      channelDescription: 'Persistent SOS Panic Button',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true, // Makes it persistent/non-swipeable
      autoCancel: false,
      styleInformation: BigTextStyleInformation(''),
      actions: [
        AndroidNotificationAction(
          'trigger_sos',
          '🚨 QUICK SOS',
          showsUserInterface: true,
          cancelNotification: false,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'sos_category',
    );

    await _notifications.show(
      888, // Unique ID for the SOS notification
      'Sentinel Protection Active',
      'Tap "QUICK SOS" for immediate help.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> cancelSosNotification() async {
    await _notifications.cancel(888);
  }
}
