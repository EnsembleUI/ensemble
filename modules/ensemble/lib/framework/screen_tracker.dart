import 'dart:async';
import 'package:ensemble/page_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Represents the current visible screen with all its metadata
class VisibleScreen {
  final String? screenId;
  final String? screenName;
  final bool isExternal;
  final bool isModal;
  final DateTime visibleSince;
  final Map<String, dynamic>? arguments;
  final Route? route;
  final int? viewGroupIndex; // For tracking position within ViewGroups

  VisibleScreen({
    this.screenId,
    this.screenName,
    this.isExternal = false,
    this.isModal = false,
    required this.visibleSince,
    this.arguments,
    this.route,
    this.viewGroupIndex,
  });

  @override
  String toString() {
    return 'VisibleScreen(id: $screenId, name: $screenName, external: $isExternal, modal: $isModal, viewGroupIndex: $viewGroupIndex)';
  }

  Map<String, dynamic> toMap() {
    return {
      'screenId': screenId,
      'screenName': screenName,
      'isExternal': isExternal,
      'isModal': isModal,
      'visibleSince': visibleSince.toIso8601String(),
      'arguments': arguments,
      'viewGroupIndex': viewGroupIndex,
    };
  }
}

/// Central manager for tracking the currently visible screen across all navigation scenarios
class ScreenTracker {
  static final ScreenTracker _instance = ScreenTracker._internal();
  factory ScreenTracker() => _instance;
  ScreenTracker._internal();

  VisibleScreen? _currentScreen;
  // Use a stack (List) for navigation history - push on navigate forward, pop on navigate back
  final List<VisibleScreen> _screenStack = [];
  final StreamController<VisibleScreen?> _screenChangeController =
      StreamController<VisibleScreen?>.broadcast();

  /// Stream that emits whenever the visible screen changes
  Stream<VisibleScreen?> get onScreenChange => _screenChangeController.stream;

  /// Get the currently visible screen
  VisibleScreen? get currentScreen => _currentScreen;

  /// Get the screen history stack (most recent at end)
  List<VisibleScreen> get screenHistory => List.unmodifiable(_screenStack);

  /// Track a new screen as visible
  void trackScreen({
    String? screenId,
    String? screenName,
    bool isExternal = false,
    bool isModal = false,
    Map<String, dynamic>? arguments,
    Route? route,
    int? viewGroupIndex,
  }) {
    final newScreen = VisibleScreen(
      screenId: screenId,
      screenName: screenName,
      isExternal: isExternal,
      isModal: isModal,
      visibleSince: DateTime.now(),
      arguments: arguments,
      route: route,
      viewGroupIndex: viewGroupIndex,
    );

    _setCurrentScreen(newScreen);

    if (kDebugMode) {
      print('📱 Screen Tracker: Now tracking ${newScreen.toString()}');
    }
  }

  /// Track screen from ScreenPayload
  void trackScreenFromPayload(ScreenPayload? payload, {Route? route, bool isModal = false, int? viewGroupIndex}) {
    if (payload == null) return;

    trackScreen(
      screenId: payload.screenId,
      screenName: payload.screenName,
      isExternal: payload.isExternal,
      isModal: isModal,
      arguments: payload.arguments,
      route: route,
      viewGroupIndex: viewGroupIndex,
    );
  }

  /// Handle navigation pop - restore previous screen if available
  void handleScreenPop(Route poppedRoute, Route? previousRoute) {

    // IMPORTANT: When screens are tracked without route reference (e.g., from Screen widget),
    // we can't rely on route matching. Try to restore from stack when:
    // 1. Current screen's route matches the popped route, OR
    // 2. Current screen has no route reference AND we have stack to restore from
    final shouldRestoreFromStack = _currentScreen?.route == poppedRoute ||
                                   (_currentScreen?.route == null && _screenStack.length > 1);

    if (!shouldRestoreFromStack) return;

    // Pop the current screen from stack (the one being removed)
    if (_screenStack.isNotEmpty) {
      _screenStack.removeLast();
    }

    // Get the previous screen from top of stack (now the current one)
    if (_screenStack.isNotEmpty) {
      final previousScreen = _screenStack.last;

      // Create a new instance with updated visibility time
      final restoredScreen = VisibleScreen(
        screenId: previousScreen.screenId,
        screenName: previousScreen.screenName,
        isExternal: previousScreen.isExternal,
        isModal: previousScreen.isModal,
        visibleSince: DateTime.now(),
        arguments: previousScreen.arguments,
        route: previousRoute ?? previousScreen.route,
        viewGroupIndex: previousScreen.viewGroupIndex,
      );

      _setCurrentScreen(restoredScreen, isRestoringFromHistory: true);

      if (kDebugMode) {
        print('📱 Screen Tracker: Restored from stack ${restoredScreen.toString()}');
      }
      return;
    }

    // Final fallback: try to get screen info from the previousRoute if we have no stack
    if (previousRoute != null) {
      _extractAndTrackScreenFromRoute(previousRoute);
      return;
    }

    // No screen found - clear current screen
    _setCurrentScreen(null);
    if (kDebugMode) {
      print('📱 Screen Tracker: No screen after pop');
    }
  }

  /// Extract screen info from route and track it (helper method)
  void _extractAndTrackScreenFromRoute(Route route) {
    final settings = route.settings;
    if (settings.arguments is ScreenPayload) {
      final payload = settings.arguments as ScreenPayload;
      trackScreenFromPayload(
        payload,
        route: route,
        isModal: route.settings.name?.contains('modal') == true
      );
    } else if (settings.name != null) {
      // Fallback: use route name as screen identifier
      trackScreen(
        screenName: settings.name,
        route: route,
        isModal: route.settings.name?.contains('modal') == true,
      );
    }
  }

  /// Handle bottom navigation and ViewGroup screen changes (sidebar, drawer navigation)
  /// Tracks the screen with viewGroupIndex for proper restoration after backgrounding
  void handleBottomNavChange(String? screenId, String? screenName, {Map<String, dynamic>? arguments, int? viewGroupIndex}) {
    if (kDebugMode) {
      print('📱 Screen Tracker: Bottom nav change to id=$screenId, name=$screenName, index=$viewGroupIndex');
    }
    trackScreen(
      screenId: screenId,
      screenName: screenName,
      isExternal: false,
      isModal: false,
      arguments: arguments,
      viewGroupIndex: viewGroupIndex,
    );
  }

  /// Handle ViewGroup screen changes (sidebar, drawer navigation)
  /// Tracks the screen with viewGroupIndex for proper restoration after backgrounding
  void handleViewGroupChange(String? screenId, String? screenName, {Map<String, dynamic>? arguments, int? viewGroupIndex}) {
    if (kDebugMode) {
      print('📱 Screen Tracker: ViewGroup change to id=$screenId, name=$screenName, index=$viewGroupIndex');
    }
    trackScreen(
      screenId: screenId,
      screenName: screenName,
      isExternal: false,
      isModal: false,
      arguments: arguments,
      viewGroupIndex: viewGroupIndex,
    );
  }

  /// Clear current screen tracking
  void clearCurrentScreen() {
    _setCurrentScreen(null);
    if (kDebugMode) {
      print('📱 Screen Tracker: Cleared current screen');
    }
  }

  /// Clear all tracking data (useful for testing)
  void clearAll() {
    _currentScreen = null;
    _screenStack.clear();
    if (kDebugMode) {
      print('📱 Screen Tracker: Cleared all tracking data');
    }
  }

  /// Get screen identifier (prefer screenName over screenId)
  String? getCurrentScreenIdentifier() {
    return _currentScreen?.screenName ?? _currentScreen?.screenId;
  }

  /// Check if a specific screen is currently visible
  bool isScreenVisible({String? screenId, String? screenName}) {
    if (_currentScreen == null) return false;
    if (screenId != null && _currentScreen!.screenId == screenId) return true;
    if (screenName != null && _currentScreen!.screenName == screenName) return true;
    return false;
  }

  /// Get current screen metadata as Map for debugging/logging
  Map<String, dynamic>? getCurrentScreenMetadata() {
    return _currentScreen?.toMap();
  }

  /// Get current ViewGroup index if the current screen is in a ViewGroup
  int? getCurrentViewGroupIndex() {
    return _currentScreen?.viewGroupIndex;
  }

  /// Check if current screen is in a ViewGroup
  bool isCurrentScreenInViewGroup() {
    return _currentScreen?.viewGroupIndex != null;
  }

  void _setCurrentScreen(VisibleScreen? screen, {bool isRestoringFromHistory = false}) {
    _currentScreen = screen;

    // Push to stack if it's a new screen (but not when restoring from stack on back navigation)
    if (screen != null && !isRestoringFromHistory) {
      _screenStack.add(screen); // Push to stack

      // Keep stack manageable (last 50 screens)
      if (_screenStack.length > 50) {
        _screenStack.removeAt(0); // Remove oldest
      }
    }

    // Print current screen info for real-time tracking
    if (screen != null) {
      final identifier = screen.screenName ?? screen.screenId ?? 'unknown';
      print('🔥 SCREEN TRACKER: $identifier');
    } else {
      print('🔥 SCREEN TRACKER: [NO SCREEN] - cleared');
    }

    // Notify listeners
    _screenChangeController.add(screen);
  }

  /// Dispose resources
  void dispose() {
    _screenChangeController.close();
  }
}

/// Navigator observer that integrates with ScreenTracker
class ScreenTrackingNavigatorObserver extends NavigatorObserver {
  final ScreenTracker _tracker = ScreenTracker();

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);

    // Extract screen info from route if available
    _extractAndTrackScreenFromRoute(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);

    // Handle screen pop with previous route info
    _tracker.handleScreenPop(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    if (newRoute != null) {
      _extractAndTrackScreenFromRoute(newRoute);
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);

    // Handle screen removal with previous route info
    _tracker.handleScreenPop(route, previousRoute);
  }

  void _extractAndTrackScreenFromRoute(Route route) {
    // Try to extract screen information from route settings
    final settings = route.settings;

    if (kDebugMode) {
      print('📱 Extracting screen from route: name=${settings.name}, args=${settings.arguments?.runtimeType}');
    }

    if (settings.arguments is ScreenPayload) {
      final payload = settings.arguments as ScreenPayload;
      if (kDebugMode) {
        print('📱 Found ScreenPayload: id=${payload.screenId}, name=${payload.screenName}');
      }
      _tracker.trackScreenFromPayload(
        payload,
        route: route,
        isModal: route.settings.name?.contains('modal') == true
      );
    } else if (settings.name != null && settings.name != '/') {
      // Skip generic routes like '/' as they don't provide useful screen information
      if (kDebugMode) {
        print('📱 Using route name as screen identifier: ${settings.name}');
      }
      _tracker.trackScreen(
        screenName: settings.name,
        route: route,
        isModal: route.settings.name?.contains('modal') == true,
      );
    } else {
      if (kDebugMode) {
        print('📱 Skipping generic route: ${settings.name} - will be handled by ViewGroup or Screen widget');
      }
      // Don't track generic routes - let ViewGroup or Screen widget handle it
    }
  }
}