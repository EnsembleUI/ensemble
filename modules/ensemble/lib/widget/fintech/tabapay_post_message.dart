import 'dart:convert';

/// Builds JavaScript that forwards `postMessage` payloads to the WebView
/// [messageHandler] channel only when `event.origin` matches the origin of
/// [pageUrl].
///
/// Returns `null` when [pageUrl] is not a valid absolute `http`/`https` URI so
/// callers can fail closed instead of installing an unrestricted listener.
String? buildTabaPayPostMessageListenerScript(String pageUrl) {
  final uri = Uri.tryParse(pageUrl);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }
  final origin = uri.origin;
  if (origin.isEmpty) {
    return null;
  }
  final originLiteral = jsonEncode(origin);
  return '''
window.addEventListener("message", function(event) {
  if (event.origin !== $originLiteral) {
    return;
  }
  messageHandler.postMessage(event.data);
});
''';
}
