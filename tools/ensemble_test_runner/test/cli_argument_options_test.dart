import 'package:ensemble_test_runner/cli/cli_argument_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses a bounded default for command-line runs', () {
    expect(
      CliArgumentOptions.timeoutSeconds(const []),
      CliArgumentOptions.defaultTimeoutSeconds,
    );
  });

  test('preserves an explicit timeout', () {
    expect(
      CliArgumentOptions.timeoutSeconds(const ['--timeout=45s']),
      45,
    );
  });

  test('accepts an explicit duration unit', () {
    expect(
      CliArgumentOptions.timeoutSeconds(const ['--timeout=2m']),
      120,
    );
  });
}
