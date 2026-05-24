import 'package:quick_actions/quick_actions.dart';
import 'package:flutter/material.dart';
import 'sos_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class ShortcutService {
  static final ShortcutService _instance = ShortcutService._internal();
  factory ShortcutService() => _instance;
  ShortcutService._internal();

  final QuickActions _quickActions = const QuickActions();
  final SosService _sosService = SosService();
  final AuthService _authService = AuthService();

  void init(BuildContext context) {
    _quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_sos') {
        _handleGlobalSosTrigger(context);
      }
    });

    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_sos',
        localizedTitle: '🚨 TRIGGER SOS',
        icon: 'ic_launcher', // Using default app icon for reliability
      ),
    ]);
  }

  Future<void> _handleGlobalSosTrigger(BuildContext context) async {
    final UserModel? user = await _authService.getCurrentUser();
    if (user != null) {
      // Trigger SOS logic
      await _sosService.triggerSos(user.uid, user.name, user.guardianPhones);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 SOS Triggered via Shortcut!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
