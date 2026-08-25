import 'package:ensemble/navigation/browser/navigation_browser_history_base.dart';
import 'package:ensemble/navigation/browser/navigation_browser_history_stub.dart'
    if (dart.library.html) 'package:ensemble/navigation/browser/navigation_browser_history_web.dart'
    as platform;

export 'navigation_browser_history_base.dart';

/// Creates the web adapter or a no-op adapter on native platforms.
NavigationBrowserHistory createNavigationBrowserHistory(
        BrowserHistoryRestore onRestore) =>
    platform.createNavigationBrowserHistory(onRestore);
