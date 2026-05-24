import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'twilio_service.dart';

/// Handles phone-based OTP generation, Firestore storage, and sending via Twilio (SMS/Call).
class PhoneOtpService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TwilioService _twilio = TwilioService();
  
  static const int _maxAttempts = 5;
  static const int _maxSends = 3;
  static const int _expiryMinutes = 5;

  String _generateOtp() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  /// Generates an OTP, saves it to Firestore, and sends it to [phone] via [method].
  Future<void> sendOtp(String phone, {bool useCall = false}) async {
    final docRef = _db.collection('phone_otps').doc(phone.trim());
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final sendCount = (data['sendCount'] ?? 0) as int;
      if (sendCount >= _maxSends && DateTime.now().isBefore(expiresAt)) {
        throw Exception(
            'Too many OTP requests. Please wait $_expiryMinutes minutes.');
      }
    }

    final otp = _generateOtp();
    final expiresAt = DateTime.now().add(const Duration(minutes: _expiryMinutes));

    await docRef.set({
      'code': otp,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'attempts': 0,
      'sendCount': FieldValue.increment(1),
      'phone': phone.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    bool success;
    if (useCall) {
      success = await _twilio.sendOtpCall(phone, otp);
    } else {
      success = await _twilio.sendSmsOtp(phone, otp);
    }

    if (!success) {
      throw Exception('Failed to deliver OTP. Please check the phone number and Twilio settings.');
    }
  }

  /// Verifies the [code] for [phone].
  Future<void> verifyOtp(String phone, String code) async {
    final docRef = _db.collection('phone_otps').doc(phone.trim());
    final doc = await docRef.get();

    if (!doc.exists) {
      throw Exception('No OTP found. Please request a new one.');
    }

    final data = doc.data()!;
    final storedCode = data['code'] as String;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    final attempts = (data['attempts'] ?? 0) as int;

    if (DateTime.now().isAfter(expiresAt)) {
      await docRef.delete();
      throw Exception('OTP has expired.');
    }

    final newAttempts = attempts + 1;
    await docRef.update({'attempts': newAttempts});

    if (newAttempts > _maxAttempts) {
      await docRef.delete();
      throw Exception('Too many failed attempts.');
    }

    if (storedCode != code.trim()) {
      throw Exception('Incorrect OTP code.');
    }

    // Success
    await docRef.delete();
  }
}
