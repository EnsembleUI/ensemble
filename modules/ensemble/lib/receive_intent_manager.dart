import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ReceiveIntentManager {
  static final ReceiveIntentManager _instance =
      ReceiveIntentManager._internal();

  ReceiveIntentManager._internal();

  factory ReceiveIntentManager() {
    return _instance;
  }

  Invokable? invokable;
  BuildContext? context;
  EnsembleAction? onReceive;
  EnsembleAction? onError;

  String? sharedText;

  void init(BuildContext context, Invokable? invokable,
      EnsembleAction? onReceive, EnsembleAction? onError) {
    this.context = context;
    this.invokable = invokable;
    this.onReceive = onReceive;
    this.onError = onError;

    receiveMediaWhenInMemory();
    receiveMediaWhenClosed();
  }

  /// For sharing images coming from outside the app while the app is in the memory
  void receiveMediaWhenInMemory() {
    ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (context != null && onReceive != null) {
        final medias = _getMedias(value);
        _addToContext(context!, medias);
        ScreenController().executeAction(context!, onReceive!);
        // Tell the library that we are done processing the intent.
        ReceiveSharingIntent.instance.reset();
      }
    }, onError: (err) {
      if (context != null && onError != null) {
        ScreenController().executeAction(context!, onError!,
            event: EnsembleEvent(invokable, data: {'error': err}));
      }
    });
  }

  /// For sharing images coming from outside the app while the app is closed
  void receiveMediaWhenClosed() {
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (context != null && onReceive != null) {
        final medias = _getMedias(value);
        _addToContext(context!, medias);
        ScreenController().executeAction(context!, onReceive!);
        // Tell the library that we are done processing the intent.
        ReceiveSharingIntent.instance.reset();
      }
    }, onError: (err) {
      if (context != null && onError != null) {
        ScreenController().executeAction(context!, onError!,
            event: EnsembleEvent(invokable, data: {'error': err}));
      }
    });
  }

  void _addToContext(BuildContext context, List<Map<String, dynamic>>? medias) {
    Ensemble.externalDataContext.addAll({
      'receiveIntentData': {'medias': medias}
    });
    ScreenController()
        .getScopeManager(context)
        ?.dataContext
        .addDataContext(Ensemble.externalDataContext);
  }

  List<Map<String, dynamic>>? _getMedias(List<SharedMediaFile> medias) {
    if (medias.isEmpty) return null;
    final datas = medias.map((e) {
      return {
        'data': e.path,
        'mimeType': e.mimeType,
        'type': e.type.name,
        'thumbnail': e.thumbnail,
      };
    }).toList();
    return datas;
  }
}
