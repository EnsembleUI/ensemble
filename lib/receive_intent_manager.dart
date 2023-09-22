import 'dart:async';

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

  late StreamSubscription _intentDataStreamSubscription;
  List<SharedMediaFile>? _sharedFiles;
  String? sharedText;

  void init() {
    // receiveMediaWhenInMemory();
    receiveMediaWhenClosed();
    // receiveTextUrlWhenInMemory();
    receiveTextUrlWhenClosed();
  }

  void deinit() {
    _intentDataStreamSubscription.cancel();
  }

  /// For sharing images coming from outside the app while the app is in the memory
  void receiveMediaWhenInMemory() {
    _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      _sharedFiles = value;
      final filePath = (_sharedFiles?.map((f) => f.path).join(",") ?? "");
      if (context != null && onReceive != null) {
        print("Shared Media: InMemory - $filePath");
        ScreenController().executeAction(context!, onReceive!,
            event: EnsembleEvent(invokable, data: {'file': filePath}));
      }
    }, onError: (err) {
      print("getIntentDataStream error: $err");
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
        print("Shared Media: Closed - $filePath");
        ScreenController().executeAction(context!, onReceive!,
            event: EnsembleEvent(invokable, data: {'file': filePath}));
      }
    });
  }

  /// For sharing or opening urls/text coming from outside the app while the app is in the memory
  void receiveTextUrlWhenInMemory() {
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getTextStream().listen((String value) {
      sharedText = value;
      if (context != null && onReceive != null && value.isNotEmpty) {
        print("Shared Text - In Memory: $sharedText");
        ScreenController().executeAction(context!, onReceive!,
            event: EnsembleEvent(invokable, data: {'text': sharedText}));
      }
    }, onError: (err) {
      print("getLinkStream error: $err");
    });
  }

  /// For sharing or opening urls/text coming from outside the app while the app is closed
  void receiveTextUrlWhenClosed() {
    ReceiveSharingIntent.getInitialText().then((String? value) {
      sharedText = value;
      if (context != null && onReceive != null && value != null) {
        print("Shared Text - Closed: $sharedText");
        ScreenController().executeAction(context!, onReceive!,
            event: EnsembleEvent(invokable,
                data: {'text': sharedText ?? 'Not Found'}));
      }
    });
  }
}
