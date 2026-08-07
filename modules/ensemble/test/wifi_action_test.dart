import 'package:ensemble/action/wifi_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('ConnectToWifiAction.fromYaml', () {
    test('parses connect operation by default', () {
      final action = ConnectToWifiAction.fromYaml(payload: {
        'ssid': 'MyNetwork',
        'password': 'secret',
      });

      expect(action.operation, WifiOperation.connect);
      expect(action.ssid, 'MyNetwork');
      expect(action.password, 'secret');
    });

    test('parses disconnect operation', () {
      final action = ConnectToWifiAction.fromYaml(payload: {
        'operation': 'disconnect',
      });

      expect(action.operation, WifiOperation.disconnect);
    });

    test('parses optional callbacks', () {
      final action = ConnectToWifiAction.fromYaml(payload: {
        'ssid': 'MyNetwork',
        'onError': {
          'showToast': {'message': 'failed'},
        },
      });

      expect(action.onSuccess, isNull);
      expect(action.onError, isA<EnsembleAction>());
    });
  });
}
