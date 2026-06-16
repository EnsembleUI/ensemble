import 'package:ensemble/widget/fintech/tabapay_post_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildTabaPayPostMessageListenerScript', () {
    test('includes origin check for valid https iframe URL', () {
      final script = buildTabaPayPostMessageListenerScript(
        'https://iframe.tabapay.com/frame',
      );
      expect(script, isNotNull);
      expect(script, contains('"https://iframe.tabapay.com"'));
      expect(script, contains('event.origin !=='));
      expect(script, contains('messageHandler.postMessage(event.data)'));
    });

    test('returns null for invalid or non-http(s) URLs', () {
      expect(buildTabaPayPostMessageListenerScript(''), isNull);
      expect(buildTabaPayPostMessageListenerScript('not-a-url'), isNull);
      expect(
        buildTabaPayPostMessageListenerScript('javascript:alert(1)'),
        isNull,
      );
      expect(
          buildTabaPayPostMessageListenerScript('file:///etc/passwd'), isNull);
    });

    test('JSON-encodes origin literal for safe embedding in JavaScript', () {
      final script = buildTabaPayPostMessageListenerScript(
        'https://pay.example.com/frame',
      );
      expect(script, contains('"https://pay.example.com"'));
    });
  });
}
