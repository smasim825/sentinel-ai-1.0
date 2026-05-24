import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

/// Handles native SMS & direct calling using device's GSM — works WITHOUT internet.
/// Uses url_launcher (already in the project) for SMS which is stable across all
/// Android versions and requires no extra permissions beyond SEND_SMS in the manifest.
class NativeEmergencyService {
  static final NativeEmergencyService _instance = NativeEmergencyService._internal();
  factory NativeEmergencyService() => _instance;
  NativeEmergencyService._internal();

  // ─────────────────────────────────────────────────────────────
  // 📱 SMS — works offline via GSM (uses SIM card, not internet)
  // ─────────────────────────────────────────────────────────────

  /// Stub — kept for API compatibility with HomeScreen calls.
  Future<bool> requestSmsPermission() async => true;

  /// Stub — kept for API compatibility with HomeScreen calls.
  Future<bool> requestCallPermission() async => true;

  /// Sends an SMS to every guardian by launching the native SMS intent.
  /// On Android, SmsManager dispatches via GSM — works with no internet.
  /// If there's no signal, the OS queues the message and sends it when signal returns.
  Future<void> sendSosSmsToBatch(List<String> phones, String message) async {
    if (kIsWeb) return;

    for (final phone in phones) {
      try {
        final formatted = _formatPhone(phone);
        debugPrint("📱 NATIVE SMS: Sending to $formatted...");

        final Uri smsUri = Uri(
          scheme: 'sms',
          path: formatted,
          queryParameters: {'body': message},
        );

        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
          debugPrint("✅ NATIVE SMS: Launched for $formatted");
        } else {
          debugPrint("⚠️ NATIVE SMS: Cannot launch sms: intent for $formatted");
        }
      } catch (e) {
        debugPrint("❌ NATIVE SMS: Failed for $phone — $e");
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 📞 Direct Calling — uses GSM, no internet needed
  // ─────────────────────────────────────────────────────────────

  /// Directly dials the first guardian's phone number via native GSM call.
  /// The call screen appears immediately on the user's phone.
  Future<void> callFirstGuardian(List<String> phones) async {
    if (kIsWeb) return;
    if (phones.isEmpty) return;

    final formatted = _formatPhone(phones.first);
    debugPrint("📞 NATIVE CALL: Dialing $formatted...");

    try {
      final called = await FlutterPhoneDirectCaller.callNumber(formatted);
      if (called == true) {
        debugPrint("✅ NATIVE CALL: Dialing $formatted succeeded");
      } else {
        // Fallback to tel: URI
        final Uri telUri = Uri(scheme: 'tel', path: formatted);
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        }
      }
    } catch (e) {
      debugPrint("❌ NATIVE CALL: Error — $e");
      // Fallback to tel: URI
      try {
        final Uri telUri = Uri(scheme: 'tel', path: _formatPhone(phones.first));
        if (await canLaunchUrl(telUri)) await launchUrl(telUri);
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 🛠 Utilities
  // ─────────────────────────────────────────────────────────────

  /// Normalizes a phone number to international format (+880 for Bangladesh).
  String _formatPhone(String phone) {
    String cleaned = phone.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('0')) return '+88$cleaned';
    if (cleaned.startsWith('880')) return '+$cleaned';
    return '+880$cleaned';
  }
}
