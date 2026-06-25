import 'package:ensemble/framework/apiproviders/api_url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appendEncodedQueryParameters', () {
    test('percent-encodes values so extra query params cannot be injected', () {
      const url = 'https://api.example.com/search';
      const maliciousValue = 'foo&role=admin';

      final result = appendEncodedQueryParameters(url, {
        'q': maliciousValue,
        'limit': '10',
      });

      final uri = Uri.parse(result);
      expect(uri.queryParameters['q'], maliciousValue);
      expect(uri.queryParameters['limit'], '10');
      expect(uri.queryParameters.containsKey('role'), isFalse);
      expect(result, contains('q=foo%26role%3Dadmin'));
    });

    test('merges with existing query parameters on the base URL', () {
      const url = 'https://api.example.com/items?filter=active';
      const injectedValue = 'x&deleted=true';

      final result = appendEncodedQueryParameters(url, {'name': injectedValue});

      final uri = Uri.parse(result);
      expect(uri.queryParameters['filter'], 'active');
      expect(uri.queryParameters['name'], injectedValue);
      expect(uri.queryParameters.containsKey('deleted'), isFalse);
    });

    test('encodes parameter keys', () {
      const url = 'https://api.example.com/data';
      const key = 'meta&extra=1';

      final result =
          appendEncodedQueryParameters(url, {key: 'value'});

      final uri = Uri.parse(result);
      expect(uri.queryParameters[key], 'value');
      expect(uri.queryParameters.containsKey('extra'), isFalse);
    });
  });
}
