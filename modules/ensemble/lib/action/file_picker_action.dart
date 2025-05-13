import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/file_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:yaml/yaml.dart';
import 'package:ensemble/framework/event.dart';
import 'package:flutter/cupertino.dart';

enum FileSource { gallery, files }

class FilePickerAction extends EnsembleAction {
  FilePickerAction({
    required this.id,
    this.allowedExtensions,
    this.allowMultiple,
    this.allowCompression,
    this.onComplete,
    this.onError,
    this.source,
  });

  String id;
  List<String>? allowedExtensions;
  bool? allowMultiple;
  bool? allowCompression;
  EnsembleAction? onComplete;
  EnsembleAction? onError;
  FileSource? source;

  factory FilePickerAction.fromYaml({Map? payload}) {
    if (payload == null || payload['id'] == null) {
      throw LanguageError("${ActionType.pickFiles.name} requires 'id'.");
    }

    FileSource? getSource(String? source) {
      if (source == 'gallery') {
        return FileSource.gallery;
      }
      if (source == 'files') {
        return FileSource.files;
      }
      return null;
    }

    return FilePickerAction(
      id: Utils.getString(payload['id'], fallback: ''),
      allowedExtensions:
          (payload['allowedExtensions'] as YamlList?)?.cast<String>().toList(),
      allowMultiple: Utils.optionalBool(payload['allowMultiple']),
      allowCompression: Utils.optionalBool(payload['allowCompression']),
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
      source: getSource(payload['source']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      await GetIt.I<FileManager>().pickFiles(context, this, scopeManager);
    } catch (e) {
      if (onError != null) {
        await ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(null, error: e.toString()));
      }
    }
  }
}
