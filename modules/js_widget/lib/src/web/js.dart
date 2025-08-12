library js_widget_web;

import 'dart:js_interop';

///
/// A JavaScript module for eval function.
///
@JS('eval')
external void eval(String code);

/// Allows assigning a function to be callable from `window.handleMessage()`
@JS('handleMessage')
external set _handleMessage(JSFunction f);

/// Allows calling the assigned function from Dart as well.
@JS()
external void handleMessage(String id, String msg);

// void _handleMessageInDart(dynamic msg) {
//   print('Hello from Dart!');
// }
void init(final Function(String id, String msg) listener) {
  _handleMessage = listener.toJS;
  // JavaScript code may now call `functionName()` or `window.functionName()`.
}
