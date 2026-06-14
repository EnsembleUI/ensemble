import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smart_wifi_connect/smart_wifi_connect.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connect with empty SSID returns invalidArguments',
      (WidgetTester tester) async {
    final result = await SmartWifiConnect.connect(
      ssid: '',
      password: 'test',
    );
    expect(result.success, false);
    expect(result.status, SmartWifiConnectStatus.invalidArguments);
  });
}
