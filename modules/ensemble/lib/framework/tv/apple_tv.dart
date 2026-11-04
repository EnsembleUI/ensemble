import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Whether the app runs on Apple TV (tvOS).
///
/// `Platform.isIOS` is also true on tvOS, so iOS code paths run there too.
/// Use this check for anything Apple TV needs differently.
bool get isAppleTV =>
    debugIsAppleTVOverride ?? (!kIsWeb && Platform.operatingSystem == 'tvos');

/// Lets tests run the Apple TV code paths on another platform.
@visibleForTesting
bool? debugIsAppleTVOverride;

/// Directory for files Ensemble stores on Apple TV, or null elsewhere.
///
/// On a physical Apple TV only Library/Caches and tmp are writable: writes to
/// Documents fail and Application Support can't be created. The tvOS
/// simulator allows both, so this only shows on hardware. Caches can be
/// purged by the system, so anything stored here must be re-fetchable.
///
/// Returns null on other platforms so callers keep their current default.
Future<Directory?> appleTVStorageDirectory() async {
  if (!isAppleTV) return null;
  try {
    return await getApplicationCacheDirectory();
  } catch (_) {
    return getTemporaryDirectory();
  }
}
