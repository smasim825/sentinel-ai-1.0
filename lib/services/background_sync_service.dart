import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../firebase_options.dart';

const String locationSyncTask = "locationSyncTask";

// Top-level function required by Workmanager (must be outside any class)
@pragma('vm:entry-point')
void callbackDispatcher() {
  if (kIsWeb) return;
  Workmanager().executeTask((task, inputData) async {
    if (task == locationSyncTask) {
      try {
        // Initialize Firebase in headless context
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Retrieve cached user UID from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final uid = prefs.getString('uid');
        if (uid == null || uid.isEmpty) return true;

        // Get current location
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return true;

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return true;
        }

        final position = await Geolocator.getCurrentPosition();

        // Get Battery Level
        int batteryLevel = 0;
        try {
          batteryLevel = await Battery().batteryLevel;
        } catch (_) {}

        // Push to Firestore
        await FirebaseFirestore.instance.collection('locations').doc(uid).set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'battery_level': batteryLevel,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

      } catch (e) {
        return false;
      }
    }
    return true;
  });
}

class BackgroundSyncService {
  static const String _taskName = locationSyncTask;

  static Future<void> startTracking() async {
    if (kIsWeb) return;
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> stopTracking() async {
    if (kIsWeb) return;
    await Workmanager().cancelByUniqueName(_taskName);
  }
}
