// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// The Web-specific version that actually calls JavaScript for iPhone support.
class WebPermissionService {
  static Future<void> requestMotionPermission() async {
    if (kIsWeb) {
      try {
        js.context.callMethod('eval', ["""
          if (typeof DeviceMotionEvent !== 'undefined' && typeof DeviceMotionEvent.requestPermission === 'function') {
            DeviceMotionEvent.requestPermission()
              .then(response => {
                if (response == 'granted') {
                  console.log('Motion permission granted');
                }
              })
              .catch(console.error);
          }
        """]);
      } catch (e) {
        debugPrint("Web Permission Error: $e");
      }
    }
  }

  static Future<void> forceAppUpdate() async {
    if (kIsWeb) {
      try {
        js.context.callMethod('eval', ["""
          (async () => {
            console.log('Sentinel: Forcing full app update...');
            localStorage.clear();
            sessionStorage.clear();
            if ('serviceWorker' in navigator) {
              const registrations = await navigator.serviceWorker.getRegistrations();
              for (let registration of registrations) {
                await registration.unregister();
              }
            }
            window.location.reload(true);
          })();
        """]);
      } catch (e) {
        debugPrint("Web Update Error: $e");
      }
    }
  }
}
