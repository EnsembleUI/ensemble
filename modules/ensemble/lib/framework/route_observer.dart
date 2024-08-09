import 'package:ensemble/ensemble.dart';
import 'package:flutter/cupertino.dart';

// handle the listeners to listen for Route changes
mixin EnsembleRouteObserver on WithEnsemble {
  // use this to track the top-most Route
  late final AppRouteObserver _appRouteObserver;

  // Carry-over logic for the pages/bottomModal.
  late final RouteObserver<PageRoute> routeObserver;

  final List<NavigatorObserver> routeObservers = [];

  initializeRouteObservers() {
    _appRouteObserver = AppRouteObserver();
    routeObservers.add(_appRouteObserver);

    routeObserver = RouteObserver<PageRoute>();
    routeObservers.add(routeObserver);
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
