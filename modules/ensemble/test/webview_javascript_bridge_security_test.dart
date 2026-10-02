import 'package:ensemble/widget/webview/webview_javascript_bridge_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('webViewAllowedOriginFromUrl', () {
    test('returns origin for https URLs', () {
      expect(
        webViewAllowedOriginFromUrl('https://app.example.com/path'),
        'https://app.example.com',
      );
    });

    test('returns null for missing or non-http(s) schemes', () {
      expect(webViewAllowedOriginFromUrl(null), isNull);
      expect(webViewAllowedOriginFromUrl(''), isNull);
      expect(webViewAllowedOriginFromUrl('file:///etc/passwd'), isNull);
      expect(webViewAllowedOriginFromUrl('not-a-url'), isNull);
    });
  });

  group('isAllowedWebViewJavaScriptMessageOrigin', () {
    test('allows matching origins', () {
      expect(
        isAllowedWebViewJavaScriptMessageOrigin(
          messageOrigin: 'https://trusted.example',
          allowedOrigin: 'https://trusted.example',
        ),
        isTrue,
      );
    });

    test('rejects cross-origin and empty values', () {
      expect(
        isAllowedWebViewJavaScriptMessageOrigin(
          messageOrigin: 'https://evil.example',
          allowedOrigin: 'https://trusted.example',
        ),
        isFalse,
      );
      expect(
        isAllowedWebViewJavaScriptMessageOrigin(
          messageOrigin: 'https://evil.example',
          allowedOrigin: null,
        ),
        isFalse,
      );
      expect(
        isAllowedWebViewJavaScriptMessageOrigin(
          messageOrigin: '',
          allowedOrigin: 'https://trusted.example',
        ),
        isFalse,
      );
    });
  });
}
