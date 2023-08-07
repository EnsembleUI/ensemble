import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/cupertino.dart';

abstract class FileManager {
  Future<void> pickFiles(BuildContext context, FilePickerAction action,
      ScopeManager? scopeManager);
}

class FileManagerStub extends FileManager {
  @override
  Future<void> pickFiles(BuildContext context, FilePickerAction action,
      ScopeManager? scopeManager) {
    throw ConfigError(
        "File management is not enabled. Please review the Ensemble documentation.");
  }
}
