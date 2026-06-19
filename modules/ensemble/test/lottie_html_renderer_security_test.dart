import 'dart:convert';

import 'package:ensemble/widget/lottie/lottie_html_renderer_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isSafeLottieHtmlRendererId', () {
    test('accepts simple alphanumeric ids', () {
      expect(isSafeLottieHtmlRendererId('lottie_123'), isTrue);
      expect(isSafeLottieHtmlRendererId('myWidget'), isTrue);
    });

    test('rejects ids that can break generated JavaScript', () {
      expect(isSafeLottieHtmlRendererId('foo"); alert(1);//'), isFalse);
      expect(isSafeLottieHtmlRendererId('foo-bar'), isFalse);
      expect(isSafeLottieHtmlRendererId(''), isFalse);
      expect(isSafeLottieHtmlRendererId('a' * 129), isFalse);
    });
  });

  group('sanitizeLottieHtmlRendererId', () {
    test('falls back when id is unsafe', () {
      expect(
        sanitizeLottieHtmlRendererId('bad"); alert(1);//', 'lottie_safe'),
        'lottie_safe',
      );
    });
  });

  group('lottieSourceLiteral', () {
    test('JSON-encodes source URLs for safe embedding', () {
      expect(
        lottieSourceLiteral('https://cdn.example.com/anim.json'),
        jsonEncode('https://cdn.example.com/anim.json'),
      );
    });

    test('neutralizes JavaScript breakout in source URL', () {
      const malicious = '"); alert(1);//';
      final literal = lottieSourceLiteral(malicious);
      expect(literal, jsonEncode(malicious));
      expect(literal, isNot(contains('load(""); alert(1);')));
    });
  });
}
