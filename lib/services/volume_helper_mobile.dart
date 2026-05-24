import 'dart:async';
import 'dart:io';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

Future<void> setMaxVolumeImpl() async {
  try {
    // Suppress system volume overlay while programmatically setting volume
    await FlutterVolumeController.updateShowSystemUI(false);

    if (Platform.isAndroid) {
      // Apply max volume to both alarm and music streams on Android
      await FlutterVolumeController.setAndroidAudioStream(stream: AudioStream.alarm);
      await FlutterVolumeController.setVolume(1.0);

      await FlutterVolumeController.setAndroidAudioStream(stream: AudioStream.music);
      await FlutterVolumeController.setVolume(1.0);
    } else {
      // iOS / other platforms
      await FlutterVolumeController.setVolume(1.0);
    }
  } catch (_) {
    // Fail silently to prevent app crashes on platform-specific discrepancies
  }
}

Future<void> restoreVolumeSystemUIImpl() async {
  try {
    // Re-enable system volume slider popup
    await FlutterVolumeController.updateShowSystemUI(true);
  } catch (_) {
    // Fail silently
  }
}
