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

/// Sources supported by the file picker action.
enum FileSource {
  /// Selects media from the device gallery.
  gallery,
  /// Selects files from the platform file picker.
  files
}

/// Ensemble action that opens the platform file picker and stores selected files in the data context.
class FilePickerAction extends EnsembleAction {
  /// Creates a [FilePickerAction] action.
  FilePickerAction({
    required this.id,
    this.allowedExtensions,
    this.allowMultiple,
    this.allowCompression,
    this.onComplete,
    this.onError,
    this.source,
  });

  /// Identifier used to store results, target an existing resource, or correlate callbacks.
  String id;
  /// File extensions allowed by the file picker.
  List<String>? allowedExtensions;
  /// Whether multiple files can be selected.
  bool? allowMultiple;
  /// Whether selected media may be compressed by the picker.
  @Deprecated('allowCompression is deprecated and has no effect.') 
  bool? allowCompression;
  /// Action executed after the operation completes successfully.
  EnsembleAction? onComplete;
  /// Action executed when the operation fails.
  EnsembleAction? onError;
  /// File source, URL, or audio source used by the action.
  FileSource? source;

  /// Creates a [FilePickerAction] from a YAML or map action payload.
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

  /// Runs this action and opens the platform picker and stores selected files.
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
