import 'dart:io';
import 'dart:typed_data';
import 'file_helper_base.dart';

class FileHelperImpl implements FileHelper {
  @override
  Future<Uint8List> readAsBytes(String path) async {
    return await File(path).readAsBytes();
  }

  @override
  Future<void> deleteFile(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}

FileHelper getFileHelper() => FileHelperImpl();
