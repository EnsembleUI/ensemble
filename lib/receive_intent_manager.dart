import 'dart:async';

import 'package:ensemble/screen_controller.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ReceiveIntentManager {
  static final ReceiveIntentManager _instance =
      ReceiveIntentManager._internal();

  ReceiveIntentManager._internal();

  factory ReceiveIntentManager() {
    return _instance;
  }

  late StreamSubscription _intentDataStreamSubscription;
  List<SharedMediaFile>? _sharedFiles;
  String? _sharedText;

  void init() {
    receiveMediaWhenInMemory();
    receiveMediaWhenClosed();
    receiveTextUrlWhenInMemory();
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
      print("Shared:" + (_sharedFiles?.map((f) => f.path).join(",") ?? ""));
    }, onError: (err) {
      print("getIntentDataStream error: $err");
    });
  }

  /// For sharing images coming from outside the app while the app is closed
  void receiveMediaWhenClosed() {
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      _sharedFiles = value;
      print("Shared:" + (_sharedFiles?.map((f) => f.path).join(",") ?? ""));
      // ScreenController().executeGetLocationAction(scopeManager, dataContext, context, action)
    });
  }

  /// For sharing or opening urls/text coming from outside the app while the app is in the memory
  void receiveTextUrlWhenInMemory() {
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getTextStream().listen((String value) {
      _sharedText = value;
      print("Shared: $_sharedText");
    }, onError: (err) {
      print("getLinkStream error: $err");
    });
  }

  /// For sharing or opening urls/text coming from outside the app while the app is closed
  void receiveTextUrlWhenClosed() {
    ReceiveSharingIntent.getInitialText().then((String? value) {
      _sharedText = value;
      print("Shared: $_sharedText");
    });
  }
}
