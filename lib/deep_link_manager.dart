
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';

/// managing deep linking into our app. Navigate to the screen if the custom
/// scheme passes in the screenId
class DeepLinkManager {
  static final DeepLinkManager _instance = DeepLinkManager._internal();
  DeepLinkManager._internal();
  factory DeepLinkManager() {
    return _instance;
  }
  AppLinks? _appLinks;

  void init() {
    _appLinks = AppLinks();
    //_checkInitialLink();
    _appLinks!.uriLinkStream.listen(
        (uri) => _navigateToScreen(uri),
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
        _navigateToScreen(initialUri);
      }
    } catch (e) {
      log(e.toString());
    }
  }

  /// navigate to screen if the deep link specifies a screenId param
  void _navigateToScreen(Uri uri) {
    String? screenId = uri.queryParameters['screenId']?.toString();
    if (screenId != null) {
      ScreenController().navigateToScreen(Utils.globalAppKey.currentContext!, screenId: screenId);
    }
  }


}