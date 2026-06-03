import 'dart:convert';

import 'package:ensemble_bluetooth/ensemble_bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encodeBleUtf8PayloadForScriptHandler', () {
    test('wraps plain payloads as a single JSON string literal', () {
      expect(encodeBleUtf8PayloadForScriptHandler('hello'), '"hello"');
    });

    test('escapes payloads that would break naive call interpolation', () {
      const payload = r'"); rogue() //';
      final encoded = encodeBleUtf8PayloadForScriptHandler(payload);
      expect(encoded, jsonEncode(payload));
      expect(jsonDecode(encoded), payload);
    });

    test('escapes quotes, backslashes, and newlines', () {
      const payload = 'line1\nline2\t"q"\\end';
      final encoded = encodeBleUtf8PayloadForScriptHandler(payload);
      expect(jsonDecode(encoded), payload);
    });
  });
}
