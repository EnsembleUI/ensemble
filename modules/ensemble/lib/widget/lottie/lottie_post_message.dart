import 'dart:convert';

import 'package:meta/meta.dart';

/// Returns true when [origin] matches the host page [pageOrigin].
@visibleForTesting
bool isAllowedLottiePostMessageOrigin(String origin, String pageOrigin) {
  if (pageOrigin.isEmpty) {
    return false;
  }
  return origin == pageOrigin;
}

/// Parses a Lottie iframe callback JSON payload for [tag].
///
/// Returns null when [rawData] is not a valid callback object.
@visibleForTesting
Map<String, dynamic>? parseLottieCallbackMessage({
  required String rawData,
  required String tag,
}) {
  if (!rawData.contains('{')) {
    return null;
  }
  try {
    final json = jsonDecode(rawData);
    if (json is! Map) {
      return null;
    }
    if (json['tag'] != tag) {
      return null;
    }
    if (json['data'] is! String) {
      return null;
    }
    return Map<String, dynamic>.from(json);
  } catch (_) {
    return null;
  }
}

/// JSON-encoded origin literal safe to embed in generated iframe JavaScript.
@visibleForTesting
String lottieParentOriginLiteral(String pageOrigin) => jsonEncode(pageOrigin);
