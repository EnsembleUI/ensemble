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
      onSuccess: EnsembleAction.fromYaml(payload['onSuccess']),
      onFailure: EnsembleAction.fromYaml(payload['onFailure']),
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

/// Share a text (an optionally a title) to external Apps
class ShareAction extends EnsembleAction {
  ShareAction(this._text, {String? title}) : _title = title;
  String? _title;
  dynamic _text;

  factory ShareAction.from({Map? payload}) {
    if (payload == null || payload['text'] == null) {
      throw LanguageError("${ActionType.share.name} requires 'text'");
    }
    return ShareAction(payload['text'], title: payload['title']?.toString());
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    Share.share(scopeManager.dataContext.eval(_text),
        subject: Utils.optionalString(scopeManager.dataContext.eval(_title)));
    return Future.value(null);
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
