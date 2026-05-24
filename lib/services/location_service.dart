import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<Position?> getCurrentLocation() async {
    final hasPermission = await handlePermission();
    if (!hasPermission) return null;

    return await Geolocator.getCurrentPosition();
  }

  Future<void> syncLocationToCloud(String uid, Position position, int batteryLevel) async {
    await _firestore.collection('locations').doc(uid).set({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'battery_level': batteryLevel,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
