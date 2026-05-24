import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import 'core/theme.dart';
import 'providers/app_state.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/dashboard/dashboard_screen.dart';
import 'ui/screens/auth/email_otp_verification_screen.dart';
import 'firebase_options.dart';
import 'services/background_sync_service.dart';
import 'services/notification_service.dart';
import 'services/sos_service.dart';
import 'services/auth_service.dart';
import 'services/background_voice_service.dart';
import 'services/native_bridge_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Native Bridge
    NativeBridgeService.init();
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (!kIsWeb) {
      // 1. Initialize Workmanager
      await Workmanager().initialize(callbackDispatcher);

      // 2. Initialize Notifications
      await NotificationService().init();
    }
  } catch (e, stack) {
    debugPrint("Initialization Error: $e");
    debugPrint("Stack trace: $stack");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const SentinelApp(),
    ),
  );
}

class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Sentinel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D1A),
            body: Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C))),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // User is logged in, check verification status in AppState
          return Consumer<AppState>(
            builder: (context, appState, child) {
              final user = appState.currentUser;
              
              if (user == null) {
                // Still fetching user data from Firestore
                Future.microtask(() => appState.fetchUser(snapshot.data!.uid));
                return const Scaffold(
                  backgroundColor: Color(0xFF0D0D1A),
                  body: Center(child: CircularProgressIndicator(color: Color(0xFFE91E8C))),
                );
              }

              // 🛡️ SECURITY GATE: If not verified, force them to the OTP screen
              if (!user.isEmailVerified) {
                // Import the OTP screen if not already imported
                return const EmailOtpVerificationScreen(); 
              }

              return const DashboardScreen();
            },
          );
        }

        // Not logged in
        return const LoginScreen();
      },
    );
  }
}

