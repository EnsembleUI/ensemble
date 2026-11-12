import 'package:firebase_remote_config_platform_interface/src/pigeon/messages.pigeon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _remoteConfigBridgeInstalled = false;
final Map<String, Map<String, Object?>> _settingsByApp = {};
final Map<String, Map<String, Object?>> _defaultsByApp = {};

/// Installs widget-mode Remote Config behavior without fabricating fetched
/// values. The app's configured defaults remain available; there is no public
/// client REST endpoint for fetching live Remote Config values.
void ensureRemoteConfigForTest() {
  if (_remoteConfigBridgeInstalled) return;
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final codec = FirebaseRemoteConfigHostApi.pigeonChannelCodec;

  void register(
    String method,
    Future<List<Object?>> Function(List<Object?> args) handler,
  ) {
    messenger.setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.firebase_remote_config_platform_interface.FirebaseRemoteConfigHostApi.$method',
        codec,
      ),
      (Object? message) async {
        final args = message! as List<Object?>;
        try {
          return await handler(args);
        } on PlatformException catch (error) {
          return <Object?>[error.code, error.message, error.details];
        } catch (error) {
          return <Object?>['error', error.toString(), null];
        }
      },
    );
  }

  register('setConfigSettings', (args) async {
    final appName = args[0]! as String;
    final settings = args[1]! as RemoteConfigPigeonSettings;
    _settingsByApp[appName] = {
      'fetchTimeout': settings.fetchTimeoutSeconds,
      'minimumFetchInterval': settings.minimumFetchIntervalSeconds,
      'lastFetchTime': 0,
      'lastFetchStatus': 'noFetchYet',
    };
    return <Object?>[];
  });
  register('ensureInitialized', (_) async => <Object?>[]);
  register('setDefaults', (args) async {
    final appName = args[0]! as String;
    _defaultsByApp[appName] = (args[1]! as Map).cast<String, Object?>();
    return <Object?>[];
  });
  register('getProperties', (args) async {
    final appName = args[0]! as String;
    return <Object?>[
      _settingsByApp[appName] ??
          {
            'fetchTimeout': 60,
            'minimumFetchInterval': 43200,
            'lastFetchTime': 0,
            'lastFetchStatus': 'noFetchYet',
          },
    ];
  });
  register('getAll', (args) async {
    final appName = args[0]! as String;
    final defaults = _defaultsByApp[appName] ?? const <String, Object?>{};
    return <Object?>[
      {
        for (final entry in defaults.entries)
          entry.key: {'value': entry.value, 'source': 'default'},
      },
    ];
  });

  // `false` is the SDK contract for no new values activated. It leaves
  // defaults intact and avoids a spurious missing-native-channel error.
  register('fetch', (_) async => <Object?>[]);
  register('fetchAndActivate', (_) async => <Object?>[false]);
  register('activate', (_) async => <Object?>[false]);
  _remoteConfigBridgeInstalled = true;
}
