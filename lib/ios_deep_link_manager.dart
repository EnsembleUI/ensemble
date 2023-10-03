import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/services.dart';

class IOSDeepLinkManager {
  static final IOSDeepLinkManager _instance = IOSDeepLinkManager._internal();
  static const MethodChannel _platform = MethodChannel('com.tin.mobile');

  // This method is invoked from the Host(iOS) Platform AppDelegate.swift
  static const String _deepLinkMethod = "urlOpened";

  IOSDeepLinkManager._internal();

  factory IOSDeepLinkManager() {
    return _instance;
  }

  void init() {
    _platform.setMethodCallHandler((call) {
      if (call.method == IOSDeepLinkManager._deepLinkMethod) {
        final url = Uri.parse(call.arguments);
        Future.delayed(const Duration(seconds: 6), () {
          _navigateToScreen(url);
        });
      }
      return Future.value(true);
    });
  }

  /// navigate to screen if the deep link specifies a screenId param
  void _navigateToScreen(Uri uri) {
    String? screenId =
        (uri.queryParameters['screenId'] ?? uri.queryParameters['screenid'])
            ?.toString();
    if (screenId != null) {
      ScreenController().navigateToScreen(Utils.globalAppKey.currentContext!,
          screenId: screenId);
    }
  }
}
