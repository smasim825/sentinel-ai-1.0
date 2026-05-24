import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'voice_trigger_service.dart';
import 'sos_service.dart';
import 'auth_service.dart';

class BackgroundVoiceService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Standard Android Notification for the Foreground Service
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'voice_trigger_service',
      'Sentinel Voice Monitoring',
      description: 'Keeps "Sentinel" voice trigger active in background.',
      importance: Importance.low, // Lower importance so it's not annoying but stays alive
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'voice_trigger_service',
        initialNotificationTitle: 'Sentinel Protection Active',
        initialNotificationContent: 'Listening for "Sentinel" command...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false, // iOS doesn't support this easily
        onForeground: onStart,
      ),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // 1. Initialize Firebase in the background isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final VoiceTriggerService voiceService = VoiceTriggerService();
    final SosService sosService = SosService();
    final AuthService authService = AuthService();

    // 2. Initialize Voice Monitoring
    await voiceService.init(() async {
      // 🚨 THIS IS THE TRIGGER!
      final user = await authService.getCurrentUser();
      if (user != null) {
        await sosService.triggerSos(user.uid, user.name, user.guardianPhones);
        
        // Update notification to show alert was sent
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "🚨 SOS ACTIVATED!",
            content: "Emergency alerts sent to your guardians.",
          );
        }
      }
    });

    // 3. Start Listening with the user's saved code
    final user = await authService.getCurrentUser();
    voiceService.startListening(customCode: user?.voiceTriggerCode);

    // Keep service alive and responding to commands
    service.on('stopService').listen((event) {
      voiceService.stopListening();
      service.stopSelf();
    });

    service.on('stopListening').listen((event) {
      voiceService.stopListening();
    });

    service.on('startListening').listen((event) async {
      final user = await authService.getCurrentUser();
      voiceService.startListening(customCode: user?.voiceTriggerCode);
    });
  }
}
