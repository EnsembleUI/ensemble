import 'package:ensemble/framework/dotenv_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDotEnvBundleContent', () {
    test('returns empty map for empty or whitespace-only input', () {
      expect(parseDotEnvBundleContent(''), isEmpty);
      expect(parseDotEnvBundleContent('   \n\t  '), isEmpty);
    });

    test('parses simple assignments and ignores blank lines', () {
      expect(
        parseDotEnvBundleContent('''
FOO=bar

BAZ=42
'''),
        {'FOO': 'bar', 'BAZ': '42'},
      );
    });

    test('strips export keyword and supports CRLF', () {
      expect(
        parseDotEnvBundleContent('export X=1\r\nexport Y=two'),
        {'X': '1', 'Y': 'two'},
      );
    });

    test('allows unquoted values that contain additional equals signs', () {
      expect(
        parseDotEnvBundleContent('URL=https://example.com/path?q=a=b'),
        {'URL': 'https://example.com/path?q=a=b'},
      );
    });

    test('parses double-quoted values with spaces', () {
      expect(
        parseDotEnvBundleContent('MSG="hello world"'),
        {'MSG': 'hello world'},
      );
    });

    test('parses single-quoted values including apostrophe via escape', () {
      expect(
        parseDotEnvBundleContent(r"S='it\'s fine'"),
        {'S': "it's fine"},
      );
    });

    test('interpolates earlier variables into later lines', () {
      expect(
        parseDotEnvBundleContent(r'''
BASE=https://api.example
PATH=/v1/users
FULL=$BASE$PATH
'''),
        {
          'BASE': 'https://api.example',
          'PATH': '/v1/users',
          'FULL': 'https://api.example/v1/users',
        },
      );
    });

    test('treats escaped dollar as literal and leaves unknown vars empty', () {
      expect(
        parseDotEnvBundleContent(r'LIT=\$HOME'),
        {'LIT': r'$HOME'},
      );
      expect(
        parseDotEnvBundleContent('UNKNOWN=\$MISSING'),
        {'UNKNOWN': ''},
      );
    });

    test('last duplicate key wins (bundle merge overwrites)', () {
      expect(
        parseDotEnvBundleContent('''
KEY=first
KEY=second
'''),
        {'KEY': 'second'},
      );
    });

    test('drops whole-line comments and trailing comments outside quotes', () {
      expect(
        parseDotEnvBundleContent('''
# KEY=ignored
REAL=1
'''),
        {'REAL': '1'},
      );
      expect(
        parseDotEnvBundleContent('KEY=value # not part of value'),
        {'KEY': 'value'},
      );
    });
  });
}
