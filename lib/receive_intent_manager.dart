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

  List<SharedMediaFile>? _sharedFiles;
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
    ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> value) {
      _sharedFiles = value;
      final filePath = (_sharedFiles?.map((f) => f.path).join(",") ?? "");
      if (context != null && onReceive != null) {
        ScreenController().executeAction(context!, onReceive!,
            event: EnsembleEvent(invokable, data: {'file': filePath}));
      }
      // Tell the library that we are done processing the intent.
      ReceiveSharingIntent.reset();
    }, onError: (err) {
      if (context != null && onError != null) {
        ScreenController().executeAction(context!, onError!,
            event: EnsembleEvent(invokable, data: {'error': err}));
      }
    });
  }

  /// For sharing images coming from outside the app while the app is closed
  void receiveMediaWhenClosed() {
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      _sharedFiles = value;
      final filePath = (_sharedFiles?.map((f) => f.path).join(",") ?? "");
      if (context != null &&
          onReceive != null &&
          _sharedFiles != null &&
          _sharedFiles!.isNotEmpty) {
        ScreenController().executeAction(context!, onReceive!,
            event: EnsembleEvent(invokable, data: {'file': filePath}));
        // Tell the library that we are done processing the intent.
        ReceiveSharingIntent.reset();
      }
    }, onError: (err) {
      if (context != null && onError != null) {
        ScreenController().executeAction(context!, onError!,
            event: EnsembleEvent(invokable, data: {'error': err}));
      }
    });
  }
}
