import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../home/home_screen.dart';
import '../chat/chat_list_screen.dart';
import '../profile/profile_screen.dart';
import '../../../services/notification_service.dart';
import '../../../services/background_voice_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/sos_service.dart';

import '../../../services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _showSosShortcut();
  }

  void _showSosShortcut() async {
    // 1. Initialize Notification Actions (for manual clicks)
    final notifications = NotificationService();
    await notifications.init();

    // 2. Show the sticky notification
    await notifications.showStickySosNotification();

    // 3. Initialize Background Voice Monitoring (Delayed slightly for smoothness)
    if (!kIsWeb) {
      Future.delayed(const Duration(seconds: 2), () async {
        await BackgroundVoiceService.initialize();
      });
    }
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1A1A2E),
          indicatorColor: const Color(0xFFE91E8C).withValues(alpha: 0.1),
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return GoogleFonts.outfit(color: const Color(0xFFE91E8C), fontWeight: FontWeight.bold, fontSize: 12);
            }
            return GoogleFonts.outfit(color: Colors.white38, fontSize: 12);
          }),
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(color: Color(0xFFE91E8C), size: 28);
            }
            return const IconThemeData(color: Colors.white38, size: 24);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          elevation: 0,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'SOS',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
