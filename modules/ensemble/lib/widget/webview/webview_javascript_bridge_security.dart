import 'package:meta/meta.dart';

/// Returns true when [messageOrigin] matches [allowedOrigin].
///
/// Used by native [InAppWebView] JavaScript channel handlers to mirror the
/// origin check already applied to web iframe `postMessage` handling.
@visibleForTesting
bool isAllowedWebViewJavaScriptMessageOrigin({
  required String? messageOrigin,
  required String? allowedOrigin,
}) {
  if (messageOrigin == null || allowedOrigin == null) {
    return false;
  }
  if (messageOrigin.isEmpty || allowedOrigin.isEmpty) {
    return false;
  }
  return messageOrigin == allowedOrigin;
}

/// Derives the allowed postMessage / JS-bridge origin from the configured
/// WebView [url]. Returns null for missing or non-http(s) URLs.
@visibleForTesting
String? webViewAllowedOriginFromUrl(String? url) {
  final uri = Uri.tryParse(url ?? '');
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }
  final origin = uri.origin;
  return origin.isEmpty ? null : origin;
}
