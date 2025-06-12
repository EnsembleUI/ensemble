import 'dart:typed_data';

import 'package:ensemble/action/file_picker_action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/cupertino.dart';

abstract class FileManager {
  Future<void> pickFiles(BuildContext context, FilePickerAction action,
      ScopeManager? scopeManager);
  Future<void> saveImage(Uint8List fileBytes, {String? name});
}

class FileManagerStub extends FileManager {
  @override
  Future<void> pickFiles(BuildContext context, FilePickerAction action,
      ScopeManager? scopeManager) {
    throw ConfigError(
        "File management is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<void> saveImage(Uint8List fileBytes, {String? name}) {
    throw ConfigError(
        "File management is not enabled. Please review the Ensemble documentation.");
  }
}
