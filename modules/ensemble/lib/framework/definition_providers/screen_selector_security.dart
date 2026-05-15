import 'package:meta/meta.dart';

/// Returns true when [screen] is a single safe path segment for resolving
/// screen YAML from a remote base URL or from bundled assets under
/// `.../screens/<screen>.yaml`.
///
/// Rejects empty values, `..`, path separators, percent-encoded separators, and
/// ASCII control characters so untrusted inputs cannot traverse outside the
/// intended screens directory.
@visibleForTesting
bool isSafeRemoteScreenSelector(String screen) {
  if (screen.isEmpty || screen.length > 256) {
    return false;
  }
  if (screen.contains('..') ||
      screen.contains('/') ||
      screen.contains(r'\') ||
      screen.contains('%')) {
    return false;
  }
  if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(screen)) {
    return false;
  }
  return true;
}
