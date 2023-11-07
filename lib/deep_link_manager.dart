import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';

class DeepLinkNavigator {
  /// navigate to screen if the deep link specifies a screenId param
  void navigateToScreen(Uri uri) {
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
