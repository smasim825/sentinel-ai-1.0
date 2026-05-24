import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// Handles email-based OTP generation, Firestore storage, and sending via EmailJS.
class EmailOtpService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const int _maxAttempts = 5;
  static const int _maxSends = 3;
  static const int _expiryMinutes = 5;

  String _generateOtp() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  /// Generates an OTP, saves it to Firestore, and sends it to [email].
  /// Throws if rate-limited or sending fails.
  Future<void> sendOtp(String email, {String name = ''}) async {
    final docRef = _db.collection('email_otps').doc(email.toLowerCase());
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final sendCount = (data['sendCount'] ?? 0) as int;
      if (sendCount >= _maxSends && DateTime.now().isBefore(expiresAt)) {
        throw Exception(
            'Too many OTP requests. Please wait $_expiryMinutes minutes before trying again.');
      }
    }

    final otp = _generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: _expiryMinutes));

    await docRef.set({
      'code': otp,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'attempts': 0,
      'sendCount': FieldValue.increment(1),
      'email': email.toLowerCase(),
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _sendViaEmailJs(email, otp, name);
  }

  /// Verifies the [code] for [email]. Throws a descriptive error on failure.
  /// Deletes the OTP document on success.
  Future<void> verifyOtp(String email, String code, {bool persist = false}) async {
    final docRef = _db.collection('email_otps').doc(email.toLowerCase());
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('No OTP found for this email. Please request a new one.');
    }

    final data = doc.data()!;
    final storedCode = data['code'] as String;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    final attempts = (data['attempts'] ?? 0) as int;

    if (DateTime.now().isAfter(expiresAt)) {
      await docRef.delete();
      throw Exception('OTP has expired. Please request a new one.');
    }

    final newAttempts = attempts + 1;
    await docRef.update({'attempts': newAttempts});

    if (newAttempts > _maxAttempts) {
      await docRef.delete();
      throw Exception('Too many failed attempts. Please request a new OTP.');
    }

    if (storedCode != code.trim()) {
      final remaining = _maxAttempts - newAttempts;
      throw Exception(
          'Incorrect OTP. $remaining ${remaining == 1 ? "attempt" : "attempts"} remaining.');
    }

    // ✅ Success — remove the OTP only if persist is false
    if (!persist) {
      await docRef.delete();
    }
  }

  Future<void> _sendViaEmailJs(String toEmail, String otp, String name) async {
    if (AppConstants.emailJsServiceId == 'YOUR_SERVICE_ID') {
      // Not yet configured — log to console for development
      debugPrint('═══════════════════════════════════════════');
      debugPrint('📧 EmailJS not configured.');
      debugPrint('   OTP for $toEmail: $otp');
      debugPrint('   See lib/core/constants.dart to set up EmailJS.');
      debugPrint('═══════════════════════════════════════════');
      return;
    }

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service_id': AppConstants.emailJsServiceId,
        'template_id': AppConstants.emailJsTemplateId,
        'user_id': AppConstants.emailJsPublicKey,
        'template_params': {
          'to_email': toEmail,
          'to_name': name.isNotEmpty ? name : 'User',
          'otp_code': otp,
          'app_name': 'Sentinel',
          'expiry_minutes': _expiryMinutes.toString(),
        },
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('EmailJS error ${response.statusCode}: ${response.body}');
      throw Exception('Failed to send OTP email. Please try again.');
    }
  }
}
