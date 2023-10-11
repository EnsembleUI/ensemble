library ensemble_file_manager;

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/stub/file_manager.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_file_manager/file_extension.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

class FileManagerImpl extends FileManager {
  @override
  Future<void> pickFiles(BuildContext context, FilePickerAction action,
      ScopeManager? scopeManager) async {
    FilePicker.platform
        .pickFiles(
      type: action.allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: action.allowedExtensions,
      allowCompression: action.allowCompression ?? true,
      allowMultiple: action.allowMultiple ?? false,
    )
        .then((result) {
      if (result == null || result.files.isEmpty) {
        if (action.onError != null) ScreenController().executeAction(context, action.onError!);
        return;
      }

      final selectedFiles =
          result.files.map((file) => FileExtension.fromPlatformFile(file)).toList();
      final fileData = FileData(files: selectedFiles);
      if (scopeManager == null) return;
      scopeManager.dataContext.addDataContextById(action.id, fileData);
      scopeManager.dispatch(
          ModelChangeEvent(SimpleBindingSource(action.id), fileData));
      if (action.onComplete != null) {
        ScreenController().executeAction(context, action.onComplete!);
      }
    });
  }
}