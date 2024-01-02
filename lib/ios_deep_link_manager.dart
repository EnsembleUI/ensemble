import 'package:ensemble/deep_link_manager.dart';
import 'package:ensemble/ensemble.dart';
import 'package:flutter/services.dart';

class IOSDeepLinkManager extends DeepLinkNavigator {
  static final IOSDeepLinkManager _instance = IOSDeepLinkManager._internal();
  static const MethodChannel _platform =
      MethodChannel('com.ensembleui.host.platform');

  // This method is invoked from the Host(iOS) Platform AppDelegate.swift
  static const String _deepLinkMethod = 'urlOpened';

  IOSDeepLinkManager._internal();

  factory IOSDeepLinkManager() {
    return _instance;
  }

  void init() {
    _platform.setMethodCallHandler((call) {
      if (call.method == IOSDeepLinkManager._deepLinkMethod) {
        final url = Uri.parse(call.arguments);
        Ensemble().addCallbackAfterInitialization(
            method: () => navigateToScreen(url));
      }
      return Future.value(true);
    });
  }
}
