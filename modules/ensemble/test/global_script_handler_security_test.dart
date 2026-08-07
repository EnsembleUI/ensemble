import 'dart:convert';

import 'package:ensemble/framework/global_script_handler_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toSafeJavaScriptCallArgument', () {
    test('passes through JSON object literals', () {
      const payload = '{"data":{"link":"https://example.com"}}';
      expect(toSafeJavaScriptCallArgument(payload), payload);
    });

    test('passes through JSON-encoded string arguments', () {
      const payload = '"hello world"';
      expect(toSafeJavaScriptCallArgument(payload), payload);
    });

    test('wraps raw attacker-controlled strings as JSON string literals', () {
      const malicious = '"); alert(1); //';
      expect(
        toSafeJavaScriptCallArgument(malicious),
        jsonEncode(malicious),
      );
    });

    test('neutralizes BLE-style breakout attempts', () {
      const malicious = 'x"); evil();//';
      final safe = toSafeJavaScriptCallArgument(malicious);
      expect(safe, jsonEncode(malicious));
      expect(safe, isNot(contains('"); evil();//')));
    });
  });
}
