import 'dart:html' as html;

bool getTestMode() {
  // Parse the current URL
  Uri uri = Uri.parse(html.window.location.href);

  // Access the query parameters
  String? testMode = uri.queryParameters['testmode'];
  testMode ??= const String.fromEnvironment("testmode").toLowerCase();
  return testMode == 'true';
}
