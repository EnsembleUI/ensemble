import 'package:ensemble/util/input_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Validate IPs', () {
    // IPv4
    expect(InputValidator.ipAddress('0.0.0.0'), true);
    expect(InputValidator.ipAddress('2.12.255.54'), true);

    // IPv6
    expect(InputValidator.ipAddress('2001:0db8:85a3:0000:0000:8a2e:0370:7334'),
        true);
    expect(InputValidator.ipAddress('2345:0425:2CA1:0000:0000:0567:5673:23b5'),
        true);

    // invalids
    expect(InputValidator.ipAddress('2.12.255'), false);
    expect(InputValidator.ipAddress('2.12.255.54.12'), false);
    expect(InputValidator.ipAddress('blah'), false);
    expect(
        InputValidator.ipAddress('2345:0425:2CA1:0000:0000:0567:5673'), false);
    expect(InputValidator.ipAddress('2345.0425.2CA1.0000.0000.0567:.5673.23b5'),
        false);
  });

  test("Validate phones", () {});
}
