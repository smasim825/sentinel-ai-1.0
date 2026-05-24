import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  CameraController? _strobeController;

  Future<void> _initialize() async {
    if (_isInitialized) return;
    try {
      _cameras = await availableCameras();
      _isInitialized = true;
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  /// Takes a snapshot from a specific camera lens direction.
  /// Returns the Firebase Storage download URL.
  Future<String?> takeSnapshot({required CameraLensDirection direction, required String uid}) async {
    await _initialize();
    if (_cameras == null || _cameras!.isEmpty) return null;

    CameraDescription? targetCamera;
    try {
      targetCamera = _cameras!.firstWhere((camera) => camera.lensDirection == direction);
    } catch (_) {
      targetCamera = _cameras!.first;
    }

    CameraController controller = CameraController(
      targetCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      XFile file = await controller.takePicture();
      
      final bytes = await file.readAsBytes();
      final url = await _uploadToFirebase(bytes, uid, direction == CameraLensDirection.front ? "front" : "back");
      
      await controller.dispose();
      return url;
    } catch (e) {
      debugPrint("Error taking snapshot ($direction): $e");
      await controller.dispose();
      return null;
    }
  }

  Future<void> setFlash(bool on) async {
    if (kIsWeb) return; // Flash control on web is unreliable without a preview
    
    try {
      if (_strobeController == null) {
        await _initialize();
        if (_cameras == null || _cameras!.isEmpty) return;
        
        final backCam = _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras!.first,
        );
        
        _strobeController = CameraController(backCam, ResolutionPreset.low, enableAudio: false);
        await _strobeController!.initialize();
      }
      
      await _strobeController!.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } catch (e) {
      debugPrint("Flash error: $e");
    }
  }

  Future<void> disposeStrobe() async {
    await _strobeController?.dispose();
    _strobeController = null;
  }

  Future<String?> _uploadToFirebase(Uint8List bytes, String uid, String side) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "sos_snapshot_${side}_$timestamp.jpg";
      final ref = FirebaseStorage.instance.ref().child('sos_evidence/$uid/$fileName');
      
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Firebase upload error: $e");
      return null;
    }
  }
}
