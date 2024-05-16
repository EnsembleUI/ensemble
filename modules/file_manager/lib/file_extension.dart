import 'package:ensemble/framework/data_context.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class FileExtension {
  static File fromPlatformFile(PlatformFile file) {
    return File(file.name, file.extension, file.size, kIsWeb ? null : file.path,
        file.bytes);
  }
}
