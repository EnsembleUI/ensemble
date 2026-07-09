import 'package:firebase_auth_platform_interface/src/pigeon/messages.pigeon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _firebaseAuthBridgeInstalled = false;

class _LiveAuthSession {
  _LiveAuthSession({
    required this.idToken,
    required this.refreshToken,
    required this.uid,
    required this.expiresAtMs,
    this.email,
    this.isEmailVerified = false,
  });

  String idToken;
  final String refreshToken;
  final String uid;
  int expiresAtMs;
  final String? email;
  final bool isEmailVerified;
}

final Map<String, _LiveAuthSession> _sessionsByApp = {};

void recordLiveAuthSession({
  required String appName,
  required String idToken,
  required String refreshToken,
  required String uid,
  required int expiresAtMs,
  String? email,
  bool isEmailVerified = false,
}) {
  _sessionsByApp[appName] = _LiveAuthSession(
    idToken: idToken,
    refreshToken: refreshToken,
    uid: uid,
    expiresAtMs: expiresAtMs,
    email: email,
    isEmailVerified: isEmailVerified,
  );
}

bool hasLiveAuthSession(String appName) => _sessionsByApp.containsKey(appName);

_LiveAuthSession? liveAuthSessionForApp(String appName) =>
    _sessionsByApp[appName];

/// Bridges Firebase Auth user token pigeon calls for code paths that still use
/// [FirebaseAuth] after [LiveSignInWithCustomToken] has established a session.
void ensureLiveFirebaseAuthForTest() {
  if (_firebaseAuthBridgeInstalled) return;
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final codec = FirebaseAuthHostApi.pigeonChannelCodec;

  void registerHandler(
    String channelName,
    Future<List<Object?>> Function(List<Object?> args) handler,
  ) {
    messenger.setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(channelName, codec),
      (Object? message) async {
        final args = (message! as List<Object?>);
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

  registerHandler(
    'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerIdTokenListener',
    (args) async {
      final app = _decodeApp(args[0]);
      final channel = 'ensemble_test_runner/auth/id-token/${app.appName}';
      _mockEventChannel(channel);
      return <Object?>[channel];
    },
  );

  registerHandler(
    'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerAuthStateListener',
    (args) async {
      final app = _decodeApp(args[0]);
      final channel = 'ensemble_test_runner/auth/auth-state/${app.appName}';
      _mockEventChannel(channel);
      return <Object?>[channel];
    },
  );

  registerHandler(
    'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.signOut',
    (args) async {
      final app = _decodeApp(args[0]);
      _sessionsByApp.remove(app.appName);
      return <Object?>[];
    },
  );

  registerHandler(
    'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthUserHostApi.getIdToken',
    (args) async {
      final app = _decodeApp(args[0]);
      final session = _sessionForApp(app);
      return <Object?>[
        InternalIdTokenResult(
          token: session.idToken,
          expirationTimestamp: session.expiresAtMs,
          authTimestamp: DateTime.now().millisecondsSinceEpoch,
          issuedAtTimestamp: DateTime.now().millisecondsSinceEpoch,
          signInProvider: 'custom',
        ),
      ];
    },
  );

  _firebaseAuthBridgeInstalled = true;
}

void _mockEventChannel(String channelName) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(MethodChannel(channelName), (call) async {
    switch (call.method) {
      case 'listen':
        return 0;
      case 'cancel':
        return null;
      default:
        return null;
    }
  });
}

AuthPigeonFirebaseApp _decodeApp(Object? value) {
  if (value is AuthPigeonFirebaseApp) {
    return value;
  }
  if (value is List) {
    return AuthPigeonFirebaseApp.decode(value);
  }
  throw ArgumentError('Unexpected Firebase app argument: $value');
}

_LiveAuthSession _sessionForApp(AuthPigeonFirebaseApp app) {
  final session = _sessionsByApp[app.appName];
  if (session == null) {
    throw PlatformException(
      code: 'no-current-user',
      message: 'No signed-in Firebase user for app ${app.appName}',
    );
  }
  return session;
}
