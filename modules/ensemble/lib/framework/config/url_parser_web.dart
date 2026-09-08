// TODO(web-wasm): replace dart:html / package:js with package:web +
// dart:js_interop. Blocks the WebAssembly target only; JS build is fine.
// https://dart.dev/interop/js-interop/package-web
import 'dart:html' as html;

bool getTestMode() {
  // Parse the current URL
  Uri uri = Uri.parse(html.window.location.href);

  // Access the query parameters
  String? testMode = uri.queryParameters['testmode'];
  testMode ??= const String.fromEnvironment("testmode").toLowerCase();
  return testMode == 'true';
}
