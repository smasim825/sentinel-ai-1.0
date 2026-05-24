import 'package:flutter/services.dart';
import 'sos_service.dart';
import 'auth_service.dart';

class NativeBridgeService {
  static const MethodChannel _channel = MethodChannel('com.sentinel.app/sos');
  static final SosService _sosService = SosService();
  static final AuthService _authService = AuthService();

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'triggerSos') {
        await _handleSosTrigger();
      }
    });
  }

  static Future<void> _handleSosTrigger() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      await _sosService.triggerSos(user.uid, user.name, user.guardianPhones);
    }
  }
}
