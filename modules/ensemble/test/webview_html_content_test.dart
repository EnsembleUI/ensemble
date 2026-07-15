import 'package:ensemble/widget/webview/webview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inline WebView HTML helpers', () {
    test('resolvedWebViewOrigin prefers url over html base', () {
      expect(
        resolvedWebViewOrigin(
          url: 'https://example.com/page',
          htmlBaseUrl: 'https://ignored.test/',
        ),
        'https://example.com',
      );
    });

    test('resolvedWebViewOrigin falls back to html base url', () {
      expect(
        resolvedWebViewOrigin(htmlBaseUrl: 'https://cdn.example/app/'),
        'https://cdn.example',
      );
    });

    test('resolvedWebViewOrigin uses default base for inline html', () {
      expect(
        resolvedWebViewOrigin(),
        Uri.parse(kWebViewHtmlDefaultBaseUrl).origin,
      );
    });

    test('buildIframeHtmlDocument wraps html with base and injected script', () {
      final document = buildIframeHtmlDocument(
        html: '<p>Hello</p>',
        htmlBaseUrl: 'https://app.example/',
        injectedJavaScript: 'console.log("ready");',
      );

      expect(document, contains('<base href="https://app.example/">'));
      expect(document, contains('<p>Hello</p>'));
      expect(document, contains('<script>console.log("ready");</script>'));
    });

    test('buildIframeHtmlDocument escapes base url attribute characters', () {
      final document = buildIframeHtmlDocument(
        html: '<p>Hi</p>',
        htmlBaseUrl: 'https://app.example/path?a=1&b=2"',
      );

      expect(
        document,
        contains('<base href="https://app.example/path?a=1&amp;b=2&quot;">'),
      );
    });
  });
}
