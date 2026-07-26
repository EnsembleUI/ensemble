import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/tv/tv_focus_widget.dart';
import 'package:flutter/cupertino.dart';

// handle the listeners to listen for Route changes
mixin EnsembleRouteObserver on WithEnsemble {
  // use this to track the top-most Route
  late final AppRouteObserver _appRouteObserver;

  // Carry-over logic for the pages/bottomModal.
  late final RouteObserver<PageRoute> routeObserver;

  // Screen tracking observer
  late final ScreenTrackingNavigatorObserver _screenTrackingObserver;

  // Frees TVFocusWidget's per-route row-position memory on route exit
  late final TVFocusRouteObserver _tvFocusRouteObserver;

  final List<NavigatorObserver> routeObservers = [];

  initializeRouteObservers() {
    _appRouteObserver = AppRouteObserver();
    routeObservers.add(_appRouteObserver);

    routeObserver = RouteObserver<PageRoute>();
    routeObservers.add(routeObserver);

    _screenTrackingObserver = ScreenTrackingNavigatorObserver();
    routeObservers.add(_screenTrackingObserver);

    _tvFocusRouteObserver = TVFocusRouteObserver();
    routeObservers.add(_tvFocusRouteObserver);
  }

  // return the current top-most Route for our App
  Route? getCurrentRoute() => _appRouteObserver.currentRoute;
}

/**
 * Expose the top-most Route for our App. We use this when popping
 * routes like a bottom sheet or modal page
 */
class AppRouteObserver extends NavigatorObserver {
  // store the current top most route for our App
  Route? currentRoute;

  @override
  void didPush(Route route, Route? previousRoute) {
    currentRoute = route;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    currentRoute = previousRoute;
    super.didPop(route, previousRoute);
  }
}
