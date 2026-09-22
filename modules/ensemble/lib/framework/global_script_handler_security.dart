import 'dart:convert';

/// Coerces [inputs] into a safe JavaScript call argument for embedding in a
/// generated `functionName(<argument>)` snippet.
///
/// Valid JSON literals (including quoted strings from [jsonEncode]) are passed
/// through unchanged. Any other value is wrapped with [jsonEncode] so quotes and
/// parentheses cannot break out of the argument position.
String toSafeJavaScriptCallArgument(String inputs) {
  try {
    jsonDecode(inputs);
    return inputs;
  } on FormatException {
    return jsonEncode(inputs);
  }
}
