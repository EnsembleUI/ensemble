import 'package:flutter/foundation.dart';

/// Whether Android WebView remote debugging may be enabled for this build.
///
/// Release/profile builds must return false so production WebViews cannot be
/// inspected or scripted via chrome://inspect (CWE-489).
bool androidWebViewDebuggingEnabled() =>
    androidWebViewDebuggingEnabledForBuild(isDebugBuild: kDebugMode);

/// Build-mode gate used by [androidWebViewDebuggingEnabled] and unit tests.
bool androidWebViewDebuggingEnabledForBuild({required bool isDebugBuild}) =>
    isDebugBuild;
