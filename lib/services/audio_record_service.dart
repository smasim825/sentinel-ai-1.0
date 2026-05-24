import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'file_helper.dart';

class AudioRecordService {
  final AudioRecorder _recorder = AudioRecorder();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String?> recordAndUpload({
    required String uid,
    int durationSeconds = 7,
  }) async {
    final hasPerms = await hasPermission();
    if (!hasPerms) return null;

    try {
      String? filePath;
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        filePath = '${dir.path}/sos_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await _recorder.start(
        RecordConfig(
          encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc, 
          bitRate: 96000, 
          sampleRate: 44100
        ),
        path: filePath ?? '',
      );

      await Future.delayed(Duration(seconds: durationSeconds));

      final path = await _recorder.stop();
      if (path == null) return null;

      final storageRef = _storage
          .ref()
          .child('sos_audio')
          .child(uid)
          .child('sos_${DateTime.now().millisecondsSinceEpoch}.m4a');

      final bytes = await fileHelper.readAsBytes(path);
      final uploadTask = await storageRef.putData(bytes, SettableMetadata(contentType: 'audio/m4a'));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      await fileHelper.deleteFile(path);

      return downloadUrl;
    } catch (e) {
      debugPrint("Recording error: $e");
      return null;
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
