import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class VoiceTriggerService {
  static final VoiceTriggerService _instance = VoiceTriggerService._internal();
  factory VoiceTriggerService() => _instance;
  VoiceTriggerService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _enabled = false;
  
  // Broad list of keywords to handle different languages and accents
  final List<String> _baseKeywords = [
    // Specific Emergency Phrases
    "help sentinel",
    "emergency emergency",
    "activate sentinel",
    "sentinel help",
    
    // Core Keyword
    "sentinel",
    
    // Emergency phrases that are less common in casual talk
    "i am in danger",
    "call for help",
    
    // Phonetic spelling of "Bachao" (Bengali/Hindi for Help)
    "bachao",
    "bacao",
    
    // Bengali script (more specific)
    "আমাকে বাঁচাও", // "Save me"
    "সেন্টিনেল হেল্প", // "Sentinel Help"
  ];

  String? _userCustomCode;
  Function? _onCodeDetected;
  Timer? _restartTimer;
  DateTime? _lastTriggerTime;

  Future<bool> init(Function onCodeDetected) async {
    _onCodeDetected = onCodeDetected;
    bool available = await _speech.initialize(
      onError: (val) {
        debugPrint('Speech Error: $val');
        _handleRestart();
      },
      onStatus: (val) {
        debugPrint('Speech Status: $val');
        if (val == 'done' || val == 'notListening') {
          _handleRestart();
        }
      },
    );
    return available;
  }

  void startListening({String? customCode}) async {
    _enabled = true;
    _userCustomCode = customCode?.toLowerCase();
    _startSpeechSession();
  }

  void _startSpeechSession() async {
    if (!_enabled || _speech.isListening) return;
    
    _isListening = true;
    await _speech.listen(
      onResult: (val) {
        String heard = val.recognizedWords.toLowerCase();
        debugPrint("Heard: $heard");
        
        // 1. Check custom user code
        bool customMatch = _userCustomCode != null && heard.contains(_userCustomCode!);
        
        // 2. Check universal base keywords
        bool baseMatch = _baseKeywords.any((keyword) => heard.contains(keyword));
        
        if (customMatch || baseMatch) {
          final now = DateTime.now();
          // Updated cool-down to 10 seconds per user request
          if (_lastTriggerTime == null || now.difference(_lastTriggerTime!) > const Duration(seconds: 10)) {
            _lastTriggerTime = now;
            debugPrint("🚨 VOICE TRIGGER DETECTED!");
            _onCodeDetected?.call();
          }
        }
      },
      listenFor: const Duration(minutes: 20), // Longer sessions
      pauseFor: const Duration(seconds: 5),
      cancelOnError: false,
      partialResults: true,
      listenMode: ListenMode.deviceDefault,
    );
  }

  void _handleRestart() {
    if (_enabled) {
      _restartTimer?.cancel();
      _restartTimer = Timer(const Duration(seconds: 1), () {
        if (_enabled) _startSpeechSession();
      });
    }
  }

  void stopListening() {
    _enabled = false;
    _isListening = false;
    _restartTimer?.cancel();
    _speech.cancel();
  }
}
