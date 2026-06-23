import 'package:ensemble/framework/apiproviders/api_query_parameters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appendEncodedQueryParameters', () {
    test('percent-encodes values so extra query params cannot be injected', () {
      const maliciousValue = 'foo&admin=true';
      final result = appendEncodedQueryParameters(
        'https://api.example.com/search',
        {'q': maliciousValue},
      );

      final uri = Uri.parse(result);
      expect(uri.queryParameters['q'], maliciousValue);
      expect(uri.queryParameters.containsKey('admin'), isFalse);
      expect(result, contains('q=foo%26admin%3Dtrue'));
    });

    test('merges with existing query parameters', () {
      final result = appendEncodedQueryParameters(
        'https://api.example.com/search?limit=10',
        {'q': 'hello world'},
      );

      final uri = Uri.parse(result);
      expect(uri.queryParameters['limit'], '10');
      expect(uri.queryParameters['q'], 'hello world');
    });

    test('returns original url when params are empty', () {
      const url = 'https://api.example.com/search';
      expect(appendEncodedQueryParameters(url, {}), url);
    });
  });
}
