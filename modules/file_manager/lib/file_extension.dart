/// Helpers for converting file-picker values into Ensemble file data.
library file_extension;

import 'package:ensemble/framework/data_context.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Converts platform picker files into Ensemble file models.
class FileExtension {
  /// Creates an Ensemble [File] from a file-picker [PlatformFile].
  static File fromPlatformFile(PlatformFile file) {
    return File(file.name, file.extension, file.size, kIsWeb ? null : file.path,
        file.bytes);
  }
}
