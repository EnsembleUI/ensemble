import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_wifi_connect/smart_wifi_connect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('smart_wifi_connect');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      return {
        'success': true,
        'status': 'connected',
        'message': 'Connected to TestNetwork',
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('connect returns invalidArguments for empty SSID', () async {
    final result = await SmartWifiConnect.connect(
      ssid: '',
      password: 'pass123',
    );
    expect(result.success, false);
    expect(result.status, SmartWifiConnectStatus.invalidArguments);
    expect(log, isEmpty);
  });

  test('connect sends correct arguments via method channel', () async {
    final result = await SmartWifiConnect.connect(
      ssid: 'MyNetwork',
      password: 'secret123',
      joinOnce: true,
      rememberNetwork: false,
    );

    expect(result.success, true);
    expect(result.status, SmartWifiConnectStatus.connected);
    expect(log, hasLength(1));
    expect(log.first.method, 'connect');
    expect(log.first.arguments, {
      'ssid': 'MyNetwork',
      'password': 'secret123',
      'joinOnce': true,
      'rememberNetwork': false,
    });
  });

  test('connect handles platform exception', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      throw PlatformException(code: 'ERROR', message: 'Something went wrong');
    });

    final result = await SmartWifiConnect.connect(
      ssid: 'MyNetwork',
      password: 'pass',
    );
    expect(result.success, false);
    expect(result.status, SmartWifiConnectStatus.failed);
    expect(result.message, 'Something went wrong');
    expect(result.platformCode, 'ERROR');
  });

  test('connect handles missing plugin', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    final result = await SmartWifiConnect.connect(
      ssid: 'MyNetwork',
      password: 'pass',
    );
    expect(result.success, false);
    expect(result.status, SmartWifiConnectStatus.unsupported);
  });

  test('connect returns permission denied status', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return {
        'success': false,
        'status': 'permissionDenied',
        'message': 'Permission denied',
      };
    });

    final result = await SmartWifiConnect.connect(
      ssid: 'MyNetwork',
      password: 'pass',
    );
    expect(result.success, false);
    expect(result.status, SmartWifiConnectStatus.permissionDenied);
  });

  test('SmartWifiConnectResult toMap returns correct data', () {
    const result = SmartWifiConnectResult(
      success: true,
      status: SmartWifiConnectStatus.connected,
      message: 'OK',
      platformCode: 'alreadyAssociated',
    );
    final map = result.toMap();
    expect(map['success'], true);
    expect(map['status'], 'connected');
    expect(map['message'], 'OK');
    expect(map['platformCode'], 'alreadyAssociated');
  });
}
