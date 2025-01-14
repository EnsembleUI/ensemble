import 'dart:io';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

class CopyToClipboardAction extends EnsembleAction {
  CopyToClipboardAction(this._value,
      {super.initiator, this.onSuccess, this.onFailure});

  dynamic _value;
  EnsembleAction? onSuccess;
  EnsembleAction? onFailure;

  factory CopyToClipboardAction.from({Map? payload}) {
    if (payload == null || payload['value'] == null) {
      throw LanguageError(
          '${ActionType.copyToClipboard.name} requires the value.');
    }
    return CopyToClipboardAction(
      payload['value'],
      onSuccess: EnsembleAction.from(payload['onSuccess']),
      onFailure: EnsembleAction.from(payload['onFailure']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    String? value = Utils.optionalString(scopeManager.dataContext.eval(_value));
    if (value != null) {
      Clipboard.setData(ClipboardData(text: value)).then((_) {
        if (onSuccess != null) {
          ScreenController().executeAction(context, onSuccess!,
              event: EnsembleEvent(initiator));
        }
      }).catchError((_) {
        if (onFailure != null) {
          ScreenController().executeAction(context, onFailure!,
              event: EnsembleEvent(initiator));
        }
      });
    } else {
      if (onFailure != null) {
        ScreenController().executeAction(context, onFailure!,
            event: EnsembleEvent(initiator));
      }
    }
    return Future.value(null);
  }
}

/// Share text and files (an optionally a title) to external Apps
class ShareAction extends EnsembleAction {
  ShareAction(this._text, {String? title, dynamic files})
      : _title = title,
        _files = files;
  String? _title;
  dynamic _text;
  dynamic _files;

  factory ShareAction.from({Map? payload}) {
    if (payload == null ||
        (payload['text'] == null && payload['files'] == null)) {
      throw LanguageError(
          "${ActionType.share.name} requires 'text' or 'files'");
    }

    return ShareAction(
      payload['text'],
      title: payload['title']?.toString(),
      files: payload['files'],
    );
  }

  // Helper method to create XFile from file data
  XFile? createXFile(dynamic file) {
    final mimeType =
        lookupMimeType(file["path"] ?? '', headerBytes: file["bytes"]) ??
            'application/octet-stream';
    try {
      if (file is Map) {
        // Handle file with path
        if (file['path'] != null && file['path'].toString().isNotEmpty) {
          final String path = file['path'].toString();
          final String name = file['name']?.toString() ?? path.split('/').last;
          return XFile(path, name: name, mimeType: mimeType);
        }

        // Handle file with bytes (web)
        if (file.containsKey('bytes') && file['bytes'] != null) {
          final String name = file['name']?.toString() ?? 'file';

          return XFile.fromData(
            file['bytes'],
            name: name,
            mimeType: mimeType,
          );
        }
      } else if (file is String) {
        // Handle simple file path string
        return XFile(file, name: file.split('/').last, mimeType: mimeType);
      }
    } catch (e) {
      debugPrint('Error creating XFile: $e');
    }
    return null;
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;

      final sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      final evaluatedText =
          scopeManager.dataContext.eval(_text)?.toString() ?? '';
      final evaluatedTitle =
          Utils.optionalString(scopeManager.dataContext.eval(_title));

      // Handle file sharing
      if (_files != null) {
        final evaluatedFiles = scopeManager.dataContext.eval(_files);
        if (evaluatedFiles != null) {
          final filesList =
              evaluatedFiles is List ? evaluatedFiles : [evaluatedFiles];
          final List<XFile> xFiles = [];

          // Create XFiles
          for (var file in filesList) {
            final xFile = createXFile(file);
            if (xFile != null) {
              xFiles.add(xFile);
            }
          }

          // Share files if any were created successfully
          if (xFiles.isNotEmpty) {
            try {
              final result = await Share.shareXFiles(
                xFiles,
                text: evaluatedText,
                subject: evaluatedTitle ?? '',
                sharePositionOrigin: sharePositionOrigin,
              );

              // Handle share result
              if (result.status == ShareResultStatus.success) {
                debugPrint('Share completed successfully: ${result.raw}');
              } else {
                debugPrint('Share completed with status: ${result.status}');
              }
              return;
            } catch (e) {
              debugPrint('Error sharing files: $e');
              if (kIsWeb) {
                // On web, fall back to sharing just the text
                await Share.share(
                  evaluatedText,
                  subject: evaluatedTitle ?? '',
                  sharePositionOrigin: sharePositionOrigin,
                );
                return;
              }
              rethrow;
            }
          }
        }
      }

      // Fall back to sharing just text if no files or file sharing failed
      if (evaluatedText.isNotEmpty) {
        final result = await Share.share(
          evaluatedText,
          subject: evaluatedTitle ?? '',
          sharePositionOrigin: sharePositionOrigin,
        );

        if (result.status == ShareResultStatus.success) {
          debugPrint('Text share completed successfully: ${result.raw}');
        } else {
          debugPrint('Text share completed with status: ${result.status}');
        }
      }
    } catch (e) {
      debugPrint('ShareAction failed: $e');
      rethrow;
    }
  }
}

/// Rate an App (currently only works for iOS)
class RateAppAction extends EnsembleAction {
  RateAppAction({dynamic title, dynamic message})
      : _title = title,
        _message = message;

  // not exposed yet
  final dynamic _title;
  final dynamic _message;

  factory RateAppAction.from({Map? payload}) {
    return RateAppAction(
        title: payload?['title'], message: payload?['message']);
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    // what a mess of options on Android. TODO: add them
    if (Platform.isIOS) {
      RateMyApp rateMyApp = RateMyApp(minDays: 0, minLaunches: 0);
      rateMyApp.init().then((_) => rateMyApp.showStarRateDialog(context));
    }
    return Future.value(null);
  }
}
