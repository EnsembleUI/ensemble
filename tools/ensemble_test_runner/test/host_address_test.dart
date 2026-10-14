import 'package:ensemble_test_runner/execution/host_address.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android keeps loopback for adb reverse', () async {
    expect(
      await resolveIntegrationHostAddress(
        platform: 'android',
        emulator: true,
      ),
      isNull,
    );
    expect(
      await resolveIntegrationHostAddress(
        platform: 'android',
        emulator: false,
      ),
      isNull,
    );
  });

  test('ios simulator keeps loopback', () async {
    expect(
      await resolveIntegrationHostAddress(
        platform: 'ios',
        emulator: true,
      ),
      isNull,
    );
  });

  test('explicit host address wins', () async {
    expect(
      await resolveIntegrationHostAddress(
        platform: 'ios',
        emulator: false,
        explicitHostAddress: '192.168.1.10',
      ),
      '192.168.1.10',
    );
  });

  test('rewrites loopback service urls', () {
    expect(
      rewriteServiceUrlForDevice('http://127.0.0.1:5001/reset', '10.0.0.2'),
      'http://10.0.0.2:5001/reset',
    );
    expect(
      rewriteServiceUrlForDevice('http://api.example/reset', '10.0.0.2'),
      'http://api.example/reset',
    );
    expect(
      rewriteServiceUrlForDevice('http://localhost:9', null),
      'http://localhost:9',
    );
  });
}
