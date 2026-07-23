import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _adobeMocksInstalled = false;

/// Installs no-op Adobe Experience Platform method channel handlers so
/// [AdobeAnalyticsImpl] can initialize under [flutter test] without native SDKs.
void ensureAdobeAnalyticsMocksForTest() {
  if (_adobeMocksInstalled) return;

  const channelNames = <String>[
    'flutter_aepcore',
    'flutter_aepedge',
    'flutter_aepidentity',
    'flutter_aeplifecycle',
    'flutter_aepsignal',
    'flutter_aepedgeidentity',
    'flutter_aepedgeconsent',
    'flutter_aepassurance',
    'flutter_aepuserprofile',
  ];

  for (final name in channelNames) {
    _installAdobeChannelMock(name);
  }

  _adobeMocksInstalled = true;
}

void _installAdobeChannelMock(String channelName) {
  final channel = MethodChannel(channelName);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'sendEvent':
        return <dynamic>[];
      case 'extensionVersion':
        return 'ensemble-test';
      case 'getExperienceCloudId':
      case 'getLocationHint':
      case 'getUrlVariables':
        return null;
      case 'getIdentities':
        return <String, dynamic>{};
      case 'getUserAttributes':
        return <String, dynamic>{};
      case 'getConsents':
        return <String, dynamic>{};
      default:
        return null;
    }
  });
}
