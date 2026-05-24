import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'camera_service.dart';
import 'voice_trigger_service.dart';
import 'package:vibration/vibration.dart';
import 'volume_helper.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal() {
    _initAudio();
  }

  void _initAudio() async {
    try {
      // Pre-configure global audio context for emergency use
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
      ));
    } catch (e) {
      debugPrint("🔊 Error initializing AudioContext: $e");
    }
  }

  final AudioPlayer _player = AudioPlayer();
  final CameraService _cameraService = CameraService();
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  Timer? _strobeTimer;
  bool _isStrobeOn = false;
  StreamSubscription? _completeSub;
  Timer? _volumeTimer;

  Future<void> playSiren({bool useStrobe = true, bool loop = true}) async {
    if (_isPlaying) return;
    
    try {
      _isPlaying = true;
      
      _volumeTimer?.cancel();
      // Set volume to max immediately
      await VolumeHelper.setMaxVolume();
      // Keep enforcing maximum volume periodically to counter manual key presses
      _volumeTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        VolumeHelper.setMaxVolume();
      });
      
      // 🛑 Kill voice trigger session immediately to free audio focus
      VoiceTriggerService().stopListening();
      
      // 🛑 Kill background voice trigger session
      if (!kIsWeb) {
        try {
          final service = FlutterBackgroundService();
          if (await service.isRunning()) {
            service.invoke('stopListening');
          }
        } catch (e) {
          debugPrint("Error invoking stopListening on background service: $e");
        }
      }
      
      // ⏳ Wait for native speech session to fully release audio hardware
      await Future.delayed(const Duration(milliseconds: 500));

      // 🔊 Re-configure global audio context to use playAndRecord with speaker output
      // so it mixes with concurrent ambient recording (if enabled) and plays at max speaker volume.
      try {
        await AudioPlayer.global.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ));
      } catch (e) {
        debugPrint("🔊 Error applying AudioContext in playSiren: $e");
      }
      
      await _player.setReleaseMode(ReleaseMode.release); // Manual loop for reliability
      await _player.setVolume(1.0); 
      
      // 🔊 Playback Logic
      try {
        await _player.setSource(AssetSource('audio/siren.mp3'));
      } catch (e) {
        await _player.setSource(UrlSource('https://www.soundjay.com/emergency/sounds/siren-01.mp3'));
      }
      
      await _player.resume();

      // Reliable Manual Looping
      _completeSub?.cancel();
      if (loop) {
        _completeSub = _player.onPlayerComplete.listen((_) {
          if (_isPlaying) {
            _player.seek(Duration.zero);
            _player.resume();
          }
        });
      }


      // Start Vibration (Commented out for troubleshooting)
      /*
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [500, 500, 500, 500], repeat: 0);
      }
      */

      if (useStrobe) {
        _startStrobe();
      }
    } catch (e) {
      debugPrint("❌ Error playing siren: $e");
      _isPlaying = false;
      _volumeTimer?.cancel();
      _volumeTimer = null;
      VolumeHelper.restoreVolumeSystemUI();
    }
  }

  void _startStrobe() async {
    if (kIsWeb) return;
    
    _strobeTimer?.cancel();
    _strobeTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) async {
      _isStrobeOn = !_isStrobeOn;
      await _cameraService.setFlash(_isStrobeOn);
    });
  }

  Future<void> stopSiren() async {
    _completeSub?.cancel();
    await _player.stop();
    _isPlaying = false;
    _strobeTimer?.cancel();
    Vibration.cancel();
    await _cameraService.setFlash(false);
    await _cameraService.disposeStrobe();
    _isStrobeOn = false;

    _volumeTimer?.cancel();
    _volumeTimer = null;
    await VolumeHelper.restoreVolumeSystemUI();

    // 🟢 Restart background voice trigger session
    if (!kIsWeb) {
      try {
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          service.invoke('startListening');
        }
      } catch (e) {
        debugPrint("Error invoking startListening on background service: $e");
      }
    }
  }
}
