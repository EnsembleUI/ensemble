library js_widget_web;

import 'package:js/js.dart';

///
/// A JavaScript module for eval function.
///
@JS('eval')
external void eval(String code);

/// Allows assigning a function to be callable from `window.handleMessage()`
@JS('handleMessage')
external set _handleMessage(void Function(String id, String msg) f);

/// Allows calling the assigned function from Dart as well.
@JS()
external void handleMessage(String id, String msg);

// void _handleMessageInDart(dynamic msg) {
//   print('Hello from Dart!');
// }
void init(final Function(String id, String msg) listener) {
  _handleMessage = allowInterop(listener);
  // JavaScript code may now call `functionName()` or `window.functionName()`.
}