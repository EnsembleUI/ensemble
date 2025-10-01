/// A Flutter plugin for updating app badge counts on Android, iOS, and macOS.
///
/// This plugin provides functionality to:
/// - Update the app badge count on the launcher icon
/// - Remove the app badge
/// - Check if the current platform supports app badges
///
/// Example:
/// ```dart
/// // Update badge count
/// await FlutterAppBadger.updateBadgeCount(5);
///
/// // Remove badge
/// await FlutterAppBadger.removeBadge();
///
/// // Check if supported
/// bool isSupported = await FlutterAppBadger.isAppBadgeSupported();
/// ```
library ensemble_app_badger;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A class that provides methods to manage app badge counts on supported platforms.
///
/// The app badge is a small number that appears on the app icon in the launcher,
/// typically used to indicate the number of unread notifications or pending items.
///
/// Supported platforms:
/// - iOS (requires iOS 8.0+)
/// - Android (requires a supported launcher)
/// - macOS (requires macOS 10.14+)
class FlutterAppBadger {
  static const MethodChannel _channel =
      const MethodChannel('ppprakhar/flutter_app_badger');

  /// Updates the app badge count on the launcher icon.
  ///
  /// The [count] parameter specifies the number to display on the badge.
  /// If [count] is 0, the badge will be removed (equivalent to calling [removeBadge]).
  /// For negative numbers, the badge will typically not be shown.
  ///
  /// Returns a [Future] that completes when the badge count has been updated.
  /// The future may complete with an error if the platform doesn't support badges
  /// or if there's an issue with the native implementation.
  ///
  /// Example:
  /// ```dart
  /// // Show badge with count 5
  /// await FlutterAppBadger.updateBadgeCount(5);
  ///
  /// // Remove badge (same as calling removeBadge())
  /// await FlutterAppBadger.updateBadgeCount(0);
  /// ```
  static Future<void> updateBadgeCount(int count) async {
    final mock = _mockUpdateBadgeCount;
    if (mock != null) {
      await mock(count);
      return;
    }

    return _channel.invokeMethod('updateBadgeCount', {"count": count});
  }

  /// Removes the app badge from the launcher icon.
  ///
  /// This method clears any existing badge count, effectively hiding the badge
  /// from the app icon. This is equivalent to calling [updateBadgeCount] with a count of 0.
  ///
  /// Returns a [Future] that completes when the badge has been removed.
  /// The future may complete with an error if the platform doesn't support badges
  /// or if there's an issue with the native implementation.
  ///
  /// Example:
  /// ```dart
  /// // Remove the badge
  /// await FlutterAppBadger.removeBadge();
  /// ```
  static Future<void> removeBadge() async {
    final mock = _mockRemoveBadge;
    if (mock != null) {
      await mock();
      return;
    }

    return _channel.invokeMethod('removeBadge');
  }

  /// Checks whether the current platform supports app badges.
  ///
  /// This method determines if the device and platform combination supports
  /// displaying badge counts on the app icon. Support varies by platform:
  ///
  /// - **iOS**: Supported on iOS 8.0 and later
  /// - **Android**: Depends on the launcher implementation
  /// - **macOS**: Supported on macOS 10.14 and later
  ///
  /// Returns a [Future<bool>] that completes with `true` if badges are supported,
  /// `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// bool isSupported = await FlutterAppBadger.isAppBadgeSupported();
  /// if (isSupported) {
  ///   await FlutterAppBadger.updateBadgeCount(5);
  /// } else {
  ///   print('Badges are not supported on this platform');
  /// }
  /// ```
  static Future<bool> isAppBadgeSupported() async {
    final mock = _mockIsAppBadgeSupported;
    if (mock != null) {
      return mock();
    }

    bool? appBadgeSupported =
        await _channel.invokeMethod('isAppBadgeSupported');
    return appBadgeSupported ?? false;
  }

  static Future<void> Function(int count)? _mockUpdateBadgeCount;
  static Future<void> Function()? _mockRemoveBadge;
  static Future<bool> Function()? _mockIsAppBadgeSupported;

  /// Sets mock implementations for testing purposes.
  ///
  /// This method allows you to provide mock implementations of the badge-related
  /// methods for unit testing. When mocks are set, the actual platform channels
  /// will be bypassed and the provided mock functions will be called instead.
  ///
  /// Parameters:
  /// - [updateBadgeCount]: Mock implementation for [updateBadgeCount]
  /// - [removeBadge]: Mock implementation for [removeBadge]
  /// - [isAppBadgeSupported]: Mock implementation for [isAppBadgeSupported]
  ///
  /// Example:
  /// ```dart
  /// FlutterAppBadger.setMocks(
  ///   updateBadgeCount: (count) async => print('Mock: Badge updated to $count'),
  ///   removeBadge: () async => print('Mock: Badge removed'),
  ///   isAppBadgeSupported: () async => true,
  /// );
  /// ```
  @visibleForTesting
  static void setMocks({
    Future<void> Function(int count)? updateBadgeCount,
    Future<void> Function()? removeBadge,
    Future<bool> Function()? isAppBadgeSupported,
  }) {
    _mockUpdateBadgeCount = updateBadgeCount;
    _mockRemoveBadge = removeBadge;
    _mockIsAppBadgeSupported = isAppBadgeSupported;
  }

  /// Clears all mock implementations and restores normal functionality.
  ///
  /// This method removes any previously set mock implementations, causing the
  /// badge methods to use the actual platform channels again. This is typically
  /// called in the teardown phase of tests.
  ///
  /// Example:
  /// ```dart
  /// // In test teardown
  /// FlutterAppBadger.clearMocks();
  /// ```
  @visibleForTesting
  static void clearMocks() {
    _mockUpdateBadgeCount = null;
    _mockRemoveBadge = null;
    _mockIsAppBadgeSupported = null;
  }
}
