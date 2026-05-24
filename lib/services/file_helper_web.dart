import 'dart:typed_data';
import 'file_helper_base.dart';
import 'package:http/http.dart' as http;

class FileHelperImpl implements FileHelper {
  @override
  Future<Uint8List> readAsBytes(String path) async {
    // On web, path is a blob URL
    final response = await http.get(Uri.parse(path));
    return response.bodyBytes;
  }

  @override
  Future<void> deleteFile(String path) async {
    // No-op on web (blob URLs are cleaned up by browser or not applicable)
  }
}

FileHelper getFileHelper() => FileHelperImpl();
