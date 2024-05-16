// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';

class DeepLinkNavigator {
  /// navigate to screen if the deep link specifies a screenId param
  void navigateToScreen(dynamic data) {
    if (data is Map) {
      _globalHandler(data);
    } else if (data is Uri) {
      _legacyDeepLinkHander(data);
    }
  }

  void _globalHandler(dynamic inputs) {
    const key = 'ensemble_deeplink_handler';
    dynamic payload;
    try {
      final event = {
        'data': {
          'link': inputs,
        },
      };
      payload =
          ScreenController().runGlobalScriptHandler(key, jsonEncode(event));

      if (payload == null) {
        print(
            'DeepLinkManager: Failed to run global function with data $event');
        return;
      }
    } on Exception catch (e) {
      print("DeepLinkManager: Error receiving deeplink: $e");
    }
    if (payload is! Map) return;
    if (payload.containsKey('status') &&
        (payload['status'] as String).toLowerCase() == 'error') {
      print('DeepLinkManager: Error while running js function');
    }

    final action = NavigateScreenAction.fromMap(payload);

    ScreenController().navigateToScreen(
      Utils.globalAppKey.currentContext!,
      screenName: action.screenName,
      asModal: action.asModal,
      isExternal: action.isExternal,
      transition: action.transition,
      pageArgs: action.payload,
    );
  }

  void _legacyDeepLinkHander(Uri uri) {
    String? screenId =
        (uri.queryParameters['screenId'] ?? uri.queryParameters['screenid'])
            ?.toString();
    String? screenName =
        (uri.queryParameters['screenName'] ?? uri.queryParameters['screenName'])
            ?.toString();
    if (screenId != null || screenName != null) {
      ScreenController().navigateToScreen(Utils.globalAppKey.currentContext!,
          screenId: screenId,
          screenName: screenName,
          pageArgs: uri.queryParameters);
    } else {
      print(
          'DeepLinkManager: Failed to navigate while running deeplink handler\nuri: $uri');
    }
  }
}

/// managing deep linking into our app. Navigate to the screen if the custom
/// scheme passes in the screenId
class DeepLinkManager extends DeepLinkNavigator {
  static final DeepLinkManager _instance = DeepLinkManager._internal();

  DeepLinkManager._internal();

  factory DeepLinkManager() {
    return _instance;
  }

  AppLinks? _appLinks;

  void init() {
    _appLinks = AppLinks();
    //_checkInitialLink();
    _appLinks!.uriLinkStream.listen((uri) => navigateToScreen(uri),
        onError: (err) {
      log("Error listening to incoming links");
    });
  }

  /// this doesn't quite work since the main flow will still load
  ///  the default screen. But we don't need to check for the initial load
  void _checkInitialLink() async {
    try {
      Uri? initialUri = await _appLinks!.getInitialAppLink();
      if (initialUri != null) {
        navigateToScreen(initialUri);
      }
    } catch (e) {
      log(e.toString());
    }
  }
}
