// TODO(web-wasm): replace dart:html / package:js with package:web +
// dart:js_interop. Blocks the WebAssembly target only; JS build is fine.
// https://dart.dev/interop/js-interop/package-web
/// only import on web platform, use in conjunction with platform_stub.dart

import 'dart:js';

bool get isHtmlRenderer => context['flutterCanvasKit'] == null;
