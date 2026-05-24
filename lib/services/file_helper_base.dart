import 'dart:typed_data';
import 'package:flutter/foundation.dart';

abstract class FileHelper {
  Future<Uint8List> readAsBytes(String path);
  Future<void> deleteFile(String path);
}
