import 'package:ensemble/widget/lottie/lottie_post_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isAllowedLottiePostMessageOrigin', () {
    test('allows messages from the host page origin', () {
      expect(
        isAllowedLottiePostMessageOrigin(
          'https://app.example.com',
          'https://app.example.com',
        ),
        isTrue,
      );
    });

    test('rejects cross-origin messages', () {
      expect(
        isAllowedLottiePostMessageOrigin(
          'https://evil.example.com',
          'https://app.example.com',
        ),
        isFalse,
      );
    });

    test('rejects empty page origin', () {
      expect(isAllowedLottiePostMessageOrigin('https://app.example.com', ''),
          isFalse);
    });
  });

  group('parseLottieCallbackMessage', () {
    test('parses valid callback payloads for the expected tag', () {
      final json = parseLottieCallbackMessage(
        rawData: '{"data": "onComplete", "id": 3, "tag": "lottie_123"}',
        tag: 'lottie_123',
      );
      expect(json, isNotNull);
      expect(json!['data'], 'onComplete');
      expect(json['id'], 3);
    });

    test('rejects spoofed tags', () {
      expect(
        parseLottieCallbackMessage(
          rawData: '{"data": "onComplete", "id": 3, "tag": "other"}',
          tag: 'lottie_123',
        ),
        isNull,
      );
    });

    test('rejects non-json payloads', () {
      expect(
        parseLottieCallbackMessage(rawData: 'not-json', tag: 'lottie_123'),
        isNull,
      );
    });
  });

  group('lottieParentOriginLiteral', () {
    test('JSON-encodes origin for safe embedding in iframe JavaScript', () {
      expect(
        lottieParentOriginLiteral('https://app.example.com'),
        '"https://app.example.com"',
      );
    });
  });
}
