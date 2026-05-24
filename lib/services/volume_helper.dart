import 'volume_helper_stub.dart'
    if (dart.library.io) 'volume_helper_mobile.dart';

class VolumeHelper {
  /// Enforces maximum system volume.
  static Future<void> setMaxVolume() async {
    await setMaxVolumeImpl();
  }

  /// Restores default system volume overlay behavior.
  static Future<void> restoreVolumeSystemUI() async {
    await restoreVolumeSystemUIImpl();
  }
}
