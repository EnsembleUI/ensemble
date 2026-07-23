import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions_platform_interface/src/pigeon/messages.pigeon.dart';
import 'package:ensemble_test_runner/mocks/firebase_test_setup.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _cloudFunctionsBridgeInstalled = false;

/// Bridges Firebase Cloud Functions pigeon calls to real HTTPS callable endpoints
/// during [flutter test]. Native macOS/iOS/Android plugins are unavailable in the
/// VM test binding, so without this handler [httpsCallable] fails immediately.
void ensureLiveCloudFunctionsForTest() {
  if (_cloudFunctionsBridgeInstalled) return;
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockDecodedMessageHandler<Object?>(
    BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
      CloudFunctionsHostApi.pigeonChannelCodec,
    ),
    (Object? message) async {
      final args = (message! as List<Object?>)[0]! as Map<Object?, Object?>;
      final arguments = args.cast<String, Object?>();
      try {
        final result = await _invokeCallableOverHttp(arguments);
        return <Object?>[result];
      } on PlatformException catch (error) {
        return <Object?>[error.code, error.message, error.details];
      } catch (error) {
        return <Object?>['error', error.toString(), null];
      }
    },
  );

  messenger.setMockDecodedMessageHandler<Object?>(
    BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.registerEventChannel',
      CloudFunctionsHostApi.pigeonChannelCodec,
    ),
    (_) async => <Object?>[],
  );

  _cloudFunctionsBridgeInstalled = true;
}

Future<Object?> _invokeCallableOverHttp(Map<String, Object?> arguments) async {
  final uri = _resolveCallableUri(arguments);
  final parameters = arguments['parameters'];
  final timeoutMs = arguments['timeout'] as int? ?? 60000;

  final client = HttpClient();
  client.connectionTimeout = Duration(milliseconds: timeoutMs);

  try {
    final request = await client.postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(jsonEncode({'data': parameters}));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PlatformException(
        code: 'firebase_functions',
        message: 'HTTP ${response.statusCode} calling $uri: $body',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw PlatformException(
        code: 'firebase_functions',
        message: 'Unexpected callable response from $uri: $body',
      );
    }

    final map = Map<String, dynamic>.from(decoded);
    if (map.containsKey('error')) {
      throw PlatformException(
        code: 'firebase_functions',
        message: map['error'].toString(),
      );
    }

    final result = map['result'];
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return result;
  } finally {
    client.close();
  }
}

Uri _resolveCallableUri(Map<String, Object?> arguments) {
  final functionUri = arguments['functionUri'] as String?;
  if (functionUri != null && functionUri.isNotEmpty) {
    return Uri.parse(functionUri);
  }

  final origin = arguments['origin'] as String?;
  if (origin != null && origin.isNotEmpty) {
    return Uri.parse(origin);
  }

  final functionName = arguments['functionName'] as String?;
  if (functionName == null || functionName.isEmpty) {
    throw ArgumentError('Cloud Functions call missing functionName');
  }

  final region = (arguments['region'] as String?) ?? 'us-central1';
  final projectId = _projectIdForApp(arguments['appName'] as String?);
  if (projectId == null || projectId.isEmpty) {
    throw StateError(
      'Could not resolve Firebase projectId for Cloud Functions call. '
      'Ensure firebase_config is loaded before invoking callable APIs.',
    );
  }

  return Uri.parse(
      'https://$region-$projectId.cloudfunctions.net/$functionName');
}

String? _projectIdForApp(String? appName) {
  if (appName != null && appName.isNotEmpty) {
    final fromInit = firebaseProjectIdsByApp[appName];
    if (fromInit != null && fromInit.isNotEmpty) {
      return fromInit;
    }
  }
  try {
    final app = (appName == null ||
            appName.isEmpty ||
            appName == defaultFirebaseAppName)
        ? Firebase.app()
        : Firebase.app(appName);
    return app.options.projectId;
  } catch (_) {
    return null;
  }
}
