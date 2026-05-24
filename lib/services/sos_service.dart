import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import 'location_service.dart';
import 'chat_service.dart';
import 'twilio_service.dart';
import 'native_emergency_service.dart';

class SosService {
  final LocationService _locationService = LocationService();
  final ChatService _chatService = ChatService();
  final TwilioService _twilioService = TwilioService();
  final NativeEmergencyService _nativeEmergency = NativeEmergencyService();
  final Battery _battery = Battery();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> triggerSos(String senderId, String senderName, List<String> guardianPhones) async {
    debugPrint("🚀 SOS_SERVICE: triggerSos started for $senderName ($senderId)");
    debugPrint("🚀 SOS_SERVICE: Guardians found: ${guardianPhones.length}");

    if (guardianPhones.isEmpty) {
      debugPrint("⚠️ SOS_SERVICE: No guardians added. Cannot send alerts.");
      return;
    }

    // 0. Update SOS Status in Firestore
    await _firestore.collection('users').doc(senderId).update({'isSosActive': true});

    // 1. NATIVE SMS — Works offline via GSM (Primary method, no internet needed)
    // Build a quick SMS now before we fetch location, so it sends ASAP
    final quickMessage = "🚨 SOS ALERT! $senderName is in DANGER! Open Sentinel app immediately.";
    _nativeEmergency.sendSosSmsToBatch(guardianPhones, quickMessage);

    // 2. NATIVE DIRECT CALL — Calls first guardian's phone directly via GSM
    _nativeEmergency.callFirstGuardian(guardianPhones);

    // 3. CLOUD: Dispatch Twilio calls to ALL guardians (backup when internet available)
    if (!kIsWeb) {
      for (String phone in guardianPhones) {
        debugPrint("📞 SOS_SERVICE: Initiating Twilio call to $phone...");
        _twilioService.makeSosCall(phone, senderName);
      }
    }

    // 2. Get Location
    final position = await _locationService.getCurrentLocation();
    debugPrint("🚀 SOS_SERVICE: Position: ${position?.latitude}, ${position?.longitude}");
    
    String locationUrl = "";
    if (position != null) {
      locationUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
    }

    // 2. Get Battery Level
    String batteryDisplay = "Unknown";
    try {
      final level = await _battery.batteryLevel;
      // Many browsers return 0 or -1 if the API is restricted
      if (level > 0) {
        batteryDisplay = "$level%";
      }
    } catch (_) {}
    debugPrint("🚀 SOS_SERVICE: Battery: $batteryDisplay");

    String sosPrefix = "🚨 SOS ALERT!";
    String details = "Battery: $batteryDisplay | Location: $locationUrl";
    String formattedMessage = "$sosPrefix $details";

    // Send follow-up native SMS with real GPS location (works offline via GSM)
    if (locationUrl.isNotEmpty) {
      final locationSms = "📍 $senderName's last known location: $locationUrl";
      _nativeEmergency.sendSosSmsToBatch(guardianPhones, locationSms);
    }

    // 3. App-to-App Chat Alerts
    for (int i = 0; i < guardianPhones.length; i++) {
      final phone = guardianPhones[i];
      debugPrint("🚀 SOS_SERVICE: Processing guardian ${i+1}: $phone");
      
      final guardianUid = await _chatService.getUserByPhone(phone);
      if (guardianUid != null) {
        final chatId = _chatService.getChatRoomId(senderId, guardianUid);
        
        // Send the alert text & interactive Live Location
        await _chatService.sendMessage(chatId, senderId, formattedMessage);
        await _chatService.sendMessage(chatId, senderId, "📍 Started sharing live location (EMERGENCY)");
        
        if (position != null) {
          await _chatService.updateLiveLocation(chatId, senderId, position.latitude, position.longitude);
        }
      }
    }

    // 5. Draft SMS as backup
    if (guardianPhones.isNotEmpty) {
      String phones = guardianPhones.join(',');
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phones,
        queryParameters: <String, String>{
          'body': formattedMessage,
        },
      );
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    }
  }

  /// Stop SOS and update privacy flag
  Future<void> stopSos(String senderId) async {
    await _firestore.collection('users').doc(senderId).update({'isSosActive': false});
  }

  /// Updates location across all guardian chats during active SOS
  Future<void> updateSosLiveLocation(String senderId, List<String> guardianPhones, Position pos) async {
    for (String phone in guardianPhones) {
      final guardianUid = await _chatService.getUserByPhone(phone);
      if (guardianUid != null) {
        final chatId = _chatService.getChatRoomId(senderId, guardianUid);
        await _chatService.updateLiveLocation(
          chatId, 
          senderId, 
          pos.latitude, 
          pos.longitude,
          heading: pos.heading,
          accuracy: pos.accuracy,
          speed: pos.speed,
        );
      }
    }
  }

  Future<void> syncLocationToCloud(String uid, dynamic position, int batteryLevel) async {
     await _locationService.syncLocationToCloud(uid, position, batteryLevel);
  }

  Future<void> callPolice() async {
    final Uri callUri = Uri(
      scheme: 'tel',
      path: AppConstants.policeEmergencyNumber,
    );
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }
}
