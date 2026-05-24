import 'package:flutter/foundation.dart';

/// A safe wrapper to handle web-only permissions without crashing Android builds.
class WebPermissionService {
  static Future<void> requestMotionPermission() async {
    // This is the Mobile/Desktop version. It does nothing.
    debugPrint("Motion permission not required on this platform.");
  }

  static Future<void> forceAppUpdate() async {
    // This is the Mobile/Desktop version. It does nothing.
    debugPrint("Force update not required on this platform.");
  }
}
