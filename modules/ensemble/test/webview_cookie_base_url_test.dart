import 'package:ensemble/widget/webview/webview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvedWebViewCookieBaseUrl', () {
    test('uses url when loading a remote page', () {
      expect(
        resolvedWebViewCookieBaseUrl(
          url: 'https://example.com/page',
          html: null,
        ),
        'https://example.com/page',
      );
    });

    test('uses htmlBaseUrl when inline html clears url', () {
      expect(
        resolvedWebViewCookieBaseUrl(
          url: null,
          html: '<p>hello</p>',
          htmlBaseUrl: 'https://auth.example.com/app/',
        ),
        'https://auth.example.com/app/',
      );
    });

    test('falls back to default base url for inline html without htmlBaseUrl',
        () {
      expect(
        resolvedWebViewCookieBaseUrl(
          url: null,
          html: '<p>hello</p>',
        ),
        kWebViewHtmlDefaultBaseUrl,
      );
    });

    test('returns null when neither url nor html content is available', () {
      expect(
        resolvedWebViewCookieBaseUrl(url: null, html: null),
        isNull,
      );
      expect(
        resolvedWebViewCookieBaseUrl(url: '', html: '   '),
        isNull,
      );
    });
  });
}
