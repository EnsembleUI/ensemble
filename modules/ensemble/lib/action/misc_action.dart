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

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box!.localToGlobal(Offset.zero) & box.size;

    final evaluatedText = scopeManager.dataContext.eval(_text);
    final evaluatedTitle =
        Utils.optionalString(scopeManager.dataContext.eval(_title));

    List<XFile>? xFiles;
    if (_files != null) {
      final evaluatedFiles = scopeManager.dataContext.eval(_files);
      if (evaluatedFiles != null) {
        final filesList =
            evaluatedFiles is List ? evaluatedFiles : [evaluatedFiles];

        xFiles = filesList.map((file) {
          // Handle case where file is a Map containing file info
          if (file is Map) {
            return XFile(file['path'].toString());
          }
          // Handle case where file is a direct path string
          return XFile(file.toString());
        }).toList();
      }
    }

    if (xFiles != null && xFiles.isNotEmpty) {
      try {
        await Share.shareXFiles(
          xFiles,
          text: evaluatedText,
          subject: evaluatedTitle,
          sharePositionOrigin: sharePositionOrigin,
        );
      } catch (e) {
        // Fallback to sharing just the text if file sharing fails
        await Share.share(
          evaluatedText,
          subject: evaluatedTitle,
          sharePositionOrigin: sharePositionOrigin,
        );
      }
    } else {
      await Share.share(
        evaluatedText,
        subject: evaluatedTitle,
        sharePositionOrigin: sharePositionOrigin,
      );
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
