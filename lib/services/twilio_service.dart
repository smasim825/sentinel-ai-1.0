import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';

class TwilioService {
  Future<bool> makeSosCall(String toPhone, String friendName) async {
    final accountSid = AppConstants.twilioAccountSid;
    final authToken = AppConstants.twilioAuthToken;
    final fromNumber = AppConstants.twilioFromNumber;

    if (accountSid == "YOUR_ACCOUNT_SID" || authToken == "YOUR_AUTH_TOKEN" || accountSid.isEmpty) {
      debugPrint("❌ TWILIO: Credentials not set in constants.dart.");
      return false;
    }

    // Formatting logic
    String formattedTo = toPhone.trim();
    if (formattedTo.startsWith('+')) {
      formattedTo = '+' + formattedTo.replaceAll(RegExp(r'\D'), '');
    } else {
      formattedTo = formattedTo.replaceAll(RegExp(r'\D'), '');
      if (formattedTo.startsWith('0')) {
        formattedTo = '+88' + formattedTo;
      } else {
        formattedTo = '+880' + formattedTo;
      }
    }

    debugPrint("📡 TWILIO: SID: $accountSid");
    debugPrint("📡 TWILIO: From: $fromNumber");
    debugPrint("📡 TWILIO: To: $formattedTo");

    final url = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Calls.json');
    final twiml = '<Response><Pause length="2"/><Say>check sentinel your friend is in danger, I repeat.</Say></Response>';

    try {
      final authHeader = 'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken'));
      final response = await http.post(
        url,
        headers: {'Authorization': authHeader},
        body: {
          'From': fromNumber,
          'To': formattedTo,
          'Twiml': twiml,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        debugPrint("✅ TWILIO: Call successfully queued for $formattedTo");
        return true;
      } else {
        final error = jsonDecode(response.body);
        debugPrint("❌ TWILIO API ERROR (${response.statusCode}): ${error['message']}");
        debugPrint("❌ TWILIO FULL ERROR: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ TWILIO NETWORK/TIMEOUT ERROR: $e");
      return false;
    }
  }

  /// Sends a verification OTP via SMS
  Future<bool> sendSmsOtp(String toPhone, String otpCode) async {
    final accountSid = AppConstants.twilioAccountSid;
    final authToken = AppConstants.twilioAuthToken;
    final fromNumber = AppConstants.twilioFromNumber;

    if (accountSid == "YOUR_ACCOUNT_SID" || accountSid.isEmpty) return false;

    final url = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');
    
    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken'))},
        body: {
          'From': fromNumber,
          'To': toPhone,
          'Body': '[Sentinel] Your verification code is: $otpCode. Valid for 5 minutes.',
        },
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint("❌ TWILIO SMS ERROR: $e");
      return false;
    }
  }

  /// Sends a verification OTP via Voice Call
  Future<bool> sendOtpCall(String toPhone, String otpCode) async {
    final accountSid = AppConstants.twilioAccountSid;
    final authToken = AppConstants.twilioAuthToken;
    final fromNumber = AppConstants.twilioFromNumber;

    if (accountSid == "YOUR_ACCOUNT_SID" || accountSid.isEmpty) return false;

    final spokenOtp = otpCode.split('').join(' ');
    final twiml = '<Response><Pause length="1"/><Say>Your Sentinel verification code is: $spokenOtp. I repeat, $spokenOtp.</Say></Response>';
    final url = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Calls.json');

    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken'))},
        body: {
          'From': fromNumber,
          'To': toPhone,
          'Twiml': twiml,
        },
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint("❌ TWILIO CALL ERROR: $e");
      return false;
    }
  }
}
