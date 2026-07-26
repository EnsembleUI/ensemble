import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:ensemble_test_runner/mocks/firebase_auth_test_setup.dart';
import 'package:ensemble_test_runner/mocks/firebase_test_setup.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

bool _firestoreBridgeInstalled = false;
int _snapshotListenerCounter = 0;

/// Bridges Firestore pigeon calls to the real Firestore REST API during
/// [flutter test]. Native plugins are unavailable in the VM test binding.
void ensureLiveFirestoreForTest() {
  if (_firestoreBridgeInstalled) return;
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final codec = FirebaseFirestoreHostApi.codec;

  void register(
    String method,
    Future<List<Object?>> Function(List<Object?> args) handler,
  ) {
    messenger.setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.$method',
        codec,
      ),
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

  Future<List<Object?>> noop(List<Object?> args) async => <Object?>[];

  register('setLoggingEnabled', (_) async => <Object?>[]);
  register('enableNetwork', noop);
  register('disableNetwork', noop);
  register('clearPersistence', noop);
  register('terminate', noop);
  register('waitForPendingWrites', noop);
  register(
      'snapshotsInSyncSetup',
      (_) async => <Object?>[
            'ensemble_test_runner/firestore/snapshots-in-sync',
          ]);
  register('persistenceCacheIndexManagerRequest', noop);

  register('documentReferenceSet', (args) async {
    final app = _decodeApp(args[0]);
    final request = _decodeDocumentRequest(args[1]);
    await _LiveFirestoreRestClient().documentSet(app, request);
    return <Object?>[];
  });

  register('documentReferenceUpdate', (args) async {
    final app = _decodeApp(args[0]);
    final request = _decodeDocumentRequest(args[1]);
    await _LiveFirestoreRestClient().documentUpdate(app, request);
    return <Object?>[];
  });

  register('documentReferenceDelete', (args) async {
    final app = _decodeApp(args[0]);
    final request = _decodeDocumentRequest(args[1]);
    await _LiveFirestoreRestClient().documentDelete(app, request);
    return <Object?>[];
  });

  register('documentReferenceGet', (args) async {
    final app = _decodeApp(args[0]);
    final request = _decodeDocumentRequest(args[1]);
    final snapshot = await _LiveFirestoreRestClient().documentGet(app, request);
    return <Object?>[snapshot];
  });

  register('queryGet', (args) async {
    final app = _decodeApp(args[0]);
    final path = args[1]! as String;
    final isCollectionGroup = args[2]! as bool;
    final parameters = args[3]! as PigeonQueryParameters;
    final options = args[4]! as PigeonGetOptions;
    final snapshot = await _LiveFirestoreRestClient().queryGet(
      app,
      path: path,
      isCollectionGroup: isCollectionGroup,
      parameters: parameters,
      options: options,
    );
    return <Object?>[snapshot];
  });

  register('documentReferenceSnapshot', (args) async {
    final request = _decodeDocumentRequest(args[1]);
    final listenerId =
        'ensemble_test_runner/firestore/document/${_snapshotListenerCounter++}/${request.path}';
    _mockFirestoreEventChannel('document', listenerId);
    return <Object?>[listenerId];
  });

  register('querySnapshot', (args) async {
    final path = args[1]! as String;
    final listenerId =
        'ensemble_test_runner/firestore/query/${_snapshotListenerCounter++}/$path';
    _mockFirestoreEventChannel('query', listenerId);
    return <Object?>[listenerId];
  });

  _firestoreBridgeInstalled = true;
}

void _mockFirestoreEventChannel(String kind, String listenerId) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    MethodChannel('plugins.flutter.io/firebase_firestore/$kind/$listenerId'),
    (call) async {
      switch (call.method) {
        case 'listen':
          return 0;
        case 'cancel':
          return null;
        default:
          return null;
      }
    },
  );
}

FirestorePigeonFirebaseApp _decodeApp(Object? value) {
  if (value is FirestorePigeonFirebaseApp) return value;
  if (value is List) return FirestorePigeonFirebaseApp.decode(value);
  throw ArgumentError('Unexpected Firestore app argument: $value');
}

DocumentReferenceRequest _decodeDocumentRequest(Object? value) {
  if (value is DocumentReferenceRequest) return value;
  if (value is List) return DocumentReferenceRequest.decode(value);
  throw ArgumentError('Unexpected document request argument: $value');
}

class _LiveFirestoreRestClient {
  Future<void> documentSet(
    FirestorePigeonFirebaseApp app,
    DocumentReferenceRequest request,
  ) async {
    final encoded = _encodeDocumentFields(request.data ?? {});
    final transforms = encoded.transforms;
    final body = <String, dynamic>{
      if (encoded.fields.isNotEmpty) 'fields': encoded.fields,
      if (transforms.isNotEmpty) 'updateTransforms': transforms,
    };

    final option = request.option;
    final updateMaskPaths = <String>[];
    if (option?.merge == true) {
      updateMaskPaths.addAll(encoded.fieldPaths);
    } else if (option?.mergeFields != null && option!.mergeFields!.isNotEmpty) {
      updateMaskPaths.addAll(
        option.mergeFields!
            .map((components) => components?.whereType<String>().join('.'))
            .whereType<String>()
            .where((path) => path.isNotEmpty),
      );
    }

    await _request(
      app,
      method: 'PATCH',
      path: request.path,
      updateMaskPaths: updateMaskPaths,
      body: body,
    );
  }

  Future<void> documentUpdate(
    FirestorePigeonFirebaseApp app,
    DocumentReferenceRequest request,
  ) async {
    final encoded = _encodeDocumentFields(request.data ?? {});
    final body = <String, dynamic>{
      if (encoded.fields.isNotEmpty) 'fields': encoded.fields,
      if (encoded.transforms.isNotEmpty) 'updateTransforms': encoded.transforms,
    };
    await _request(
      app,
      method: 'PATCH',
      path: request.path,
      updateMaskPaths: encoded.fieldPaths,
      body: body,
    );
  }

  Future<void> documentDelete(
    FirestorePigeonFirebaseApp app,
    DocumentReferenceRequest request,
  ) async {
    await _request(app, method: 'DELETE', path: request.path);
  }

  Future<PigeonDocumentSnapshot> documentGet(
    FirestorePigeonFirebaseApp app,
    DocumentReferenceRequest request,
  ) async {
    final decoded = await _request(app, method: 'GET', path: request.path);
    if (decoded == null) {
      return PigeonDocumentSnapshot(
        path: request.path,
        data: null,
        metadata: PigeonSnapshotMetadata(
          hasPendingWrites: false,
          isFromCache: false,
        ),
      );
    }
    return _toPigeonDocumentSnapshot(request.path, decoded);
  }

  Future<PigeonQuerySnapshot> queryGet(
    FirestorePigeonFirebaseApp app, {
    required String path,
    required bool isCollectionGroup,
    required PigeonQueryParameters parameters,
    required PigeonGetOptions options,
  }) async {
    final structuredQuery = <String, dynamic>{
      'from': [
        if (isCollectionGroup)
          {'collectionId': path, 'allDescendants': true}
        else
          {'collectionId': path.split('/').last},
      ],
      if (parameters.limit != null) 'limit': parameters.limit,
    };

    final body = <String, dynamic>{
      'structuredQuery': structuredQuery,
    };
    if (path.contains('/') && !isCollectionGroup) {
      final parentPath = path.split('/')..removeLast();
      body['parent'] = '${_documentsRoot(app)}/${parentPath.join('/')}';
    } else {
      body['parent'] = _documentsRoot(app);
    }

    final decoded = await _request(
      app,
      method: 'POST',
      suffix: ':runQuery',
      body: body,
    );

    final documents = <PigeonDocumentSnapshot?>[];
    if (decoded is List) {
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final document = entry['document'];
        if (document is! Map) continue;
        final name = document['name']?.toString() ?? '';
        final docPath = _pathFromDocumentName(name);
        documents.add(_toPigeonDocumentSnapshot(docPath, document));
      }
    }

    return PigeonQuerySnapshot(
      documents: documents,
      documentChanges: documents
          .whereType<PigeonDocumentSnapshot>()
          .map(
            (document) => PigeonDocumentChange(
              type: DocumentChangeType.added,
              document: document,
              oldIndex: -1,
              newIndex: documents.indexOf(document),
            ),
          )
          .toList(),
      metadata: PigeonSnapshotMetadata(
        hasPendingWrites: false,
        isFromCache: options.source == Source.cache,
      ),
    );
  }

  Future<dynamic> _request(
    FirestorePigeonFirebaseApp app, {
    required String method,
    String? path,
    String suffix = '',
    List<String> updateMaskPaths = const [],
    Map<String, dynamic>? body,
  }) async {
    final projectId = _projectIdForApp(app.appName);
    final idToken = _idTokenForApp(app.appName);
    final encodedPath =
        path == null ? '' : path.split('/').map(Uri.encodeComponent).join('/');
    final queryParts = <String>[
      for (final fieldPath in updateMaskPaths)
        'updateMask.fieldPaths=${Uri.encodeQueryComponent(fieldPath)}',
    ];
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents'
      '${encodedPath.isEmpty ? '' : '/$encodedPath'}$suffix'
      '${queryParts.isEmpty ? '' : '?${queryParts.join('&')}'}',
    );

    final client = HttpClient();
    try {
      late final HttpClientRequest request;
      switch (method) {
        case 'GET':
          request = await client.getUrl(uri);
        case 'DELETE':
          request = await client.deleteUrl(uri);
        case 'PATCH':
          request = await client.patchUrl(uri);
        case 'POST':
          request = await client.postUrl(uri);
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 404 && method == 'GET') {
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PlatformException(
          code: 'firestore',
          message: 'HTTP ${response.statusCode} $method $uri: $responseBody',
        );
      }
      if (responseBody.isEmpty) {
        return null;
      }
      return jsonDecode(responseBody);
    } finally {
      client.close();
    }
  }

  String _documentsRoot(FirestorePigeonFirebaseApp app) {
    final projectId = _projectIdForApp(app.appName);
    return 'projects/$projectId/databases/(default)/documents';
  }
}

class _EncodedDocument {
  _EncodedDocument({
    required this.fields,
    required this.transforms,
    required this.fieldPaths,
  });

  final Map<String, dynamic> fields;
  final List<Map<String, dynamic>> transforms;
  final List<String> fieldPaths;
}

_EncodedDocument _encodeDocumentFields(Map<Object?, Object?> data) {
  final fields = <String, dynamic>{};
  final fieldPaths = <String>[];

  data.forEach((key, value) {
    final fieldPath = key?.toString();
    if (fieldPath == null || fieldPath.isEmpty) return;

    fields[fieldPath] = _encodeValue(value);
    fieldPaths.add(fieldPath);
  });

  return _EncodedDocument(
    fields: fields,
    transforms: const [],
    fieldPaths: fieldPaths,
  );
}

Map<String, dynamic> _encodeValue(Object? value) {
  if (value == null) return {'nullValue': null};
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': value.toString()};
  if (value is double) return {'doubleValue': value};
  if (value is String) return {'stringValue': value};
  if (value is Timestamp) {
    return {'timestampValue': value.toDate().toUtc().toIso8601String()};
  }
  if (value is GeoPoint) {
    return {
      'geoPointValue': {
        'latitude': value.latitude,
        'longitude': value.longitude,
      },
    };
  }
  if (value is Map) {
    final nested = <String, dynamic>{};
    value.forEach((key, nestedValue) {
      final nestedKey = key?.toString();
      if (nestedKey == null || nestedKey.isEmpty) return;
      nested[nestedKey] = _encodeValue(nestedValue);
    });
    return {
      'mapValue': {'fields': nested}
    };
  }
  if (value is Iterable) {
    return {
      'arrayValue': {
        'values': value.map(_encodeValue).toList(),
      },
    };
  }
  return {'stringValue': value.toString()};
}

PigeonDocumentSnapshot _toPigeonDocumentSnapshot(
  String path,
  Map<dynamic, dynamic> document,
) {
  final fields = document['fields'];
  return PigeonDocumentSnapshot(
    path: path,
    data: fields is Map
        ? _decodeFields(fields.cast<Object?, Object?>())
        : <String?, Object?>{},
    metadata: PigeonSnapshotMetadata(
      hasPendingWrites: false,
      isFromCache: false,
    ),
  );
}

Map<String?, Object?> _decodeFields(Map<Object?, Object?> fields) {
  final decoded = <String?, Object?>{};
  fields.forEach((key, value) {
    decoded[key?.toString()] = _decodeValue(value);
  });
  return decoded;
}

Object? _decodeValue(Object? value) {
  if (value is! Map) return value;
  final map = value.cast<String, dynamic>();
  if (map.containsKey('stringValue')) return map['stringValue'];
  if (map.containsKey('booleanValue')) return map['booleanValue'];
  if (map.containsKey('integerValue')) {
    return int.tryParse(map['integerValue'].toString()) ?? map['integerValue'];
  }
  if (map.containsKey('doubleValue')) {
    final raw = map['doubleValue'];
    return raw is num ? raw.toDouble() : double.tryParse(raw.toString());
  }
  if (map.containsKey('nullValue')) return null;
  if (map.containsKey('timestampValue')) {
    return Timestamp.fromDate(DateTime.parse(map['timestampValue'].toString()));
  }
  if (map.containsKey('geoPointValue')) {
    final geo = map['geoPointValue'] as Map;
    return GeoPoint(
      (geo['latitude'] as num).toDouble(),
      (geo['longitude'] as num).toDouble(),
    );
  }
  if (map.containsKey('mapValue')) {
    final nested = (map['mapValue'] as Map?)?['fields'];
    if (nested is Map) {
      return _decodeFields(nested.cast<Object?, Object?>());
    }
    return <String, dynamic>{};
  }
  if (map.containsKey('arrayValue')) {
    final values = (map['arrayValue'] as Map?)?['values'];
    if (values is List) {
      return values.map(_decodeValue).toList();
    }
    return <dynamic>[];
  }
  return map;
}

String _pathFromDocumentName(String name) {
  const marker = '/documents/';
  final index = name.indexOf(marker);
  if (index < 0) return name;
  return name.substring(index + marker.length);
}

String _projectIdForApp(String appName) {
  final fromInit = firebaseProjectIdsByApp[appName];
  if (fromInit != null && fromInit.isNotEmpty) {
    return fromInit;
  }
  try {
    final app = appName.isEmpty || appName == defaultFirebaseAppName
        ? Firebase.app()
        : Firebase.app(appName);
    return app.options.projectId;
  } catch (_) {
    throw StateError(
      'Could not resolve Firebase projectId for Firestore call (app: $appName).',
    );
  }
}

String _idTokenForApp(String appName) {
  final session = liveAuthSessionForApp(appName) ??
      liveAuthSessionForApp(defaultFirebaseAppName);
  final token = session?.idToken;
  if (token == null || token.isEmpty) {
    throw PlatformException(
      code: 'firestore',
      message:
          'No signed-in Firebase user for Firestore REST call (app: $appName).',
    );
  }
  return token;
}
