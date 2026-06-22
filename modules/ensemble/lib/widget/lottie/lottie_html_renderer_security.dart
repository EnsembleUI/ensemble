import 'dart:convert';

import 'package:meta/meta.dart';

/// Returns true when [id] is safe to embed in generated JavaScript identifiers
/// and HTML attributes for the Lottie HTML renderer iframe.
@visibleForTesting
bool isSafeLottieHtmlRendererId(String id) {
  if (id.isEmpty || id.length > 128) {
    return false;
  }
  return RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(id);
}

/// Sanitizes [id] for embedding in generated iframe JavaScript.
///
/// Falls back to [fallbackId] when [id] contains characters that would break
/// out of JS string literals or variable names.
@visibleForTesting
String sanitizeLottieHtmlRendererId(String id, String fallbackId) {
  return isSafeLottieHtmlRendererId(id) ? id : fallbackId;
}

/// JSON-encoded source URL literal safe to embed in generated iframe JS.
@visibleForTesting
String lottieSourceLiteral(String source) => jsonEncode(source);
