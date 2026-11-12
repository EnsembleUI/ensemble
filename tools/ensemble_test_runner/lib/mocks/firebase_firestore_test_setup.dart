import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/mocks/real_network_http_client.dart';

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:cloud_firestore_platform_interface/src/method_channel/utils/firestore_message_codec.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_auth_test_setup.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_test_setup.dart';
import 'firebase_pigeon_compat.dart';

bool _firestoreBridgeInstalled = false;
int _snapshotListenerCounter = 0;
bool _legacyFirestorePigeon = true;

/// Bridges Firestore pigeon calls to the real Firestore REST API during
/// `flutter test`. Native plugins are unavailable in the VM test binding.
void ensureLiveFirestoreForTest() {
  if (_firestoreBridgeInstalled) return;
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  // cloud_firestore encodes query fields as FieldPath (wire type 192), but its
  // production FirestoreMessageCodec intentionally does not decode that type.
  // Native Firestore decodes it on the other side; the widget-test messenger
  // must do so before it can invoke our live REST adapter.
  final legacyPigeon = usesLegacyFirebasePigeon(
    'cloud_firestore_platform_interface',
  );
  _legacyFirestorePigeon = legacyPigeon;
  final codec = PigeonCompatCodec(
    FirestorePigeonDecoder(legacyPigeon),
    const FirestorePigeonWireMessageCodec(),
  );

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
        } catch (error, stack) {
          return <Object?>['error', error.toString(), '$stack'];
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
    (_) async => <Object?>['ensemble_test_runner/firestore/snapshots-in-sync'],
  );
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
    final parameters = _decodeQueryParameters(args[3]!);
    final options = _decodeGetOptions(args[4]!);
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

_FirestoreApp _decodeApp(Object? value) {
  if (value is FirestorePigeonFirebaseApp) {
    return _FirestoreApp(value.appName, value.databaseURL);
  }
  if (value is PigeonWireValue && value.value is List) {
    final encoded = value.value! as List;
    return _FirestoreApp(encoded[0] as String, encoded[2] as String);
  }
  if (value is List)
    return _FirestoreApp(value[0] as String, value[2] as String);
  throw ArgumentError('Unexpected Firestore app argument: $value');
}

_DocumentRequest _decodeDocumentRequest(Object? value) {
  if (value is DocumentReferenceRequest) {
    return _DocumentRequest(value.path, value.data, value.option?.encode());
  }
  if (value is PigeonWireValue && value.value is List) {
    final encoded = value.value! as List;
    return _DocumentRequest(
        encoded[0] as String, encoded[1] as Map<Object?, Object?>?, encoded[2]);
  }
  if (value is List)
    return _DocumentRequest(
        value[0] as String, value[1] as Map<Object?, Object?>?, value[2]);
  throw ArgumentError('Unexpected document request argument: $value');
}

_QueryParameters _decodeQueryParameters(Object value) {
  if (value is PigeonWireValue && value.value is List) {
    return _QueryParameters.fromList(value.value! as List);
  }
  if (value is List) return _QueryParameters.fromList(value);
  return _QueryParameters.fromObject(value);
}

_GetOptions _decodeGetOptions(Object value) {
  if (value is PigeonWireValue && value.value is List) {
    final encoded = value.value! as List;
    return _GetOptions(_sourceIndex(encoded[0]), encoded[1]);
  }
  if (value is List) return _GetOptions(_sourceIndex(value[0]), value[1]);
  return _GetOptions((value as dynamic).source.index as int,
      (value as dynamic).serverTimestampBehavior);
}

int _sourceIndex(Object? value) => value is PigeonWireValue
    ? value.value! as int
    : value is Source
        ? value.index
        : value! as int;

class _FirestoreApp {
  const _FirestoreApp(this.appName, this.databaseURL);
  final String appName;
  final String databaseURL;
}

class _DocumentRequest {
  const _DocumentRequest(this.path, this.data, this.option);
  final String path;
  final Map<Object?, Object?>? data;
  final Object? option;
}

class _DocumentOption {
  const _DocumentOption(this.merge, this.mergeFields);
  final bool? merge;
  final List<List<String?>?>? mergeFields;
}

class _QueryParameters {
  _QueryParameters.fromList(List encoded)
      : where = _listOfLists(encoded[0]),
        orderBy = _listOfLists(encoded[1]),
        limit = encoded[2] as int?,
        limitToLast = encoded[3] as int?,
        startAt = _objectList(encoded[4]),
        startAfter = _objectList(encoded[5]),
        endAt = _objectList(encoded[6]),
        endBefore = _objectList(encoded[7]),
        filters = _objectMap(encoded[8]);

  _QueryParameters.fromObject(Object object)
      : where = (object as dynamic).where as List<List<Object?>?>?,
        orderBy = (object as dynamic).orderBy as List<List<Object?>?>?,
        limit = (object as dynamic).limit as int?,
        limitToLast = (object as dynamic).limitToLast as int?,
        startAt = (object as dynamic).startAt as List<Object?>?,
        startAfter = (object as dynamic).startAfter as List<Object?>?,
        endAt = (object as dynamic).endAt as List<Object?>?,
        endBefore = (object as dynamic).endBefore as List<Object?>?,
        filters = (object as dynamic).filters as Map<String?, Object?>?;

  final List<List<Object?>?>? where;
  final List<List<Object?>?>? orderBy;
  final int? limit;
  final int? limitToLast;
  final List<Object?>? startAt;
  final List<Object?>? startAfter;
  final List<Object?>? endAt;
  final List<Object?>? endBefore;
  final Map<String?, Object?>? filters;
}

List<List<Object?>?>? _listOfLists(Object? value) => value is List
    ? value
        .map<List<Object?>?>(
            (item) => item is List ? List<Object?>.from(item) : null)
        .toList()
    : null;

List<Object?>? _objectList(Object? value) =>
    value is List ? List<Object?>.from(value) : null;

Map<String?, Object?>? _objectMap(Object? value) => value is Map
    ? value
        .map<String?, Object?>((key, item) => MapEntry(key?.toString(), item))
    : null;

class _GetOptions {
  const _GetOptions(this.sourceIndex, this.serverTimestampBehavior);
  final int sourceIndex;
  final Object? serverTimestampBehavior;
}

class _LiveFirestoreRestClient {
  Future<void> documentSet(
    _FirestoreApp app,
    _DocumentRequest request,
  ) async {
    final encoded = _encodeDocumentFields(request.data ?? {});
    final transforms = encoded.transforms;
    final body = <String, dynamic>{
      if (encoded.fields.isNotEmpty) 'fields': encoded.fields,
      if (transforms.isNotEmpty) 'updateTransforms': transforms,
    };

    final option = _decodeDocumentOption(request.option);
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
    _FirestoreApp app,
    _DocumentRequest request,
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
    _FirestoreApp app,
    _DocumentRequest request,
  ) async {
    await _request(app, method: 'DELETE', path: request.path);
  }

  Future<PigeonWireValue> documentGet(
    _FirestoreApp app,
    _DocumentRequest request,
  ) async {
    final decoded = await _request(app, method: 'GET', path: request.path);
    if (decoded == null) {
      return _documentWire(request.path, null);
    }
    return _documentWire(request.path, decoded as Map<dynamic, dynamic>?);
  }

  Future<PigeonWireValue> queryGet(
    _FirestoreApp app, {
    required String path,
    required bool isCollectionGroup,
    required _QueryParameters parameters,
    required _GetOptions options,
  }) async {
    final filters = parameters.filters;
    final structuredQuery = <String, dynamic>{
      'from': [
        if (isCollectionGroup)
          {'collectionId': path, 'allDescendants': true}
        else
          {'collectionId': path.split('/').last},
      ],
      if (parameters.limit != null) 'limit': parameters.limit,
      if (parameters.limitToLast != null) 'limit': parameters.limitToLast,
      if (parameters.where case final where? when where.isNotEmpty)
        'where': _encodeQueryFilters(where),
      if ((parameters.where == null || parameters.where!.isEmpty) &&
          filters != null &&
          filters.isNotEmpty)
        'where': _encodeFilterMap(filters),
      if (parameters.orderBy case final orderBy? when orderBy.isNotEmpty)
        'orderBy': _encodeOrderBy(orderBy),
      if (parameters.startAt != null)
        'startAt': _encodeCursor(parameters.startAt!, inclusive: true),
      if (parameters.startAfter != null)
        'startAt': _encodeCursor(parameters.startAfter!, inclusive: false),
      if (parameters.endAt != null)
        'endAt': _encodeCursor(parameters.endAt!, inclusive: true),
      if (parameters.endBefore != null)
        'endAt': _encodeCursor(parameters.endBefore!, inclusive: false),
    };

    // Firestore's REST runQuery takes the collection's parent document in the
    // URL path. Putting `parent` in the JSON body (or using the full collection
    // path as the URL parent) is rejected by the API for subcollections.
    final parentPath = path.contains('/') && !isCollectionGroup
        ? (path.split('/')..removeLast()).join('/')
        : null;

    final decoded = await _request(
      app,
      method: 'POST',
      path: parentPath,
      suffix: ':runQuery',
      body: {'structuredQuery': structuredQuery},
    );

    final documents = <PigeonWireValue>[];
    if (decoded is List) {
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final document = entry['document'];
        if (document is! Map) continue;
        final name = document['name']?.toString() ?? '';
        final docPath = _pathFromDocumentName(name);
        documents.add(_documentWire(docPath, document));
      }
    }

    final changes = <PigeonWireValue>[
      for (var index = 0; index < documents.length; index++)
        PigeonWireValue(
          _legacyFirestorePigeon ? 132 : 142,
          <Object?>[
            if (_legacyFirestorePigeon) 0 else PigeonWireValue(129, 0),
            _legacyFirestorePigeon ? documents[index].value : documents[index],
            -1,
            index,
          ],
        ),
    ];
    return PigeonWireValue(
      _legacyFirestorePigeon ? 138 : 143,
      <Object?>[
        documents,
        changes,
        _metadataPayload(
          hasPendingWrites: false,
          isFromCache: options.sourceIndex == Source.cache.index,
        ),
      ],
    );
  }

  Future<dynamic> _request(
    _FirestoreApp app, {
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

    // Reads are safe to retry if the REST transport drops a TLS connection
    // while streaming a response. Do not replay writes: a lost write response
    // leaves its commit outcome unknown.
    final retryableRead =
        method == 'GET' || (method == 'POST' && suffix == ':runQuery');
    var attempt = 0;
    const maxReadRetries = 3;
    while (true) {
      final client = createRealNetworkHttpClient();
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
        if (idToken.isNotEmpty) {
          request.headers
              .set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
        }
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
      } catch (error) {
        if (!retryableRead ||
            attempt >= maxReadRetries ||
            error is! IOException) {
          rethrow;
        }
        attempt++;
        await Future<void>.delayed(
          Duration(milliseconds: 250 * (1 << (attempt - 1))),
        );
      } finally {
        client.close(force: true);
      }
    }
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
      'mapValue': {'fields': nested},
    };
  }
  if (value is Iterable) {
    return {
      'arrayValue': {'values': value.map(_encodeValue).toList()},
    };
  }
  return {'stringValue': value.toString()};
}

Map<String, dynamic> _encodeQueryFilters(List<List<Object?>?> conditions) {
  final filters = <Map<String, dynamic>>[];
  for (final condition in conditions) {
    if (condition == null || condition.length < 3) continue;
    filters.add(_encodeFieldFilter(condition[0], condition[1], condition[2]));
  }
  if (filters.isEmpty) {
    throw StateError(
        'Firestore query had a where clause that could not be encoded.');
  }
  if (filters.length == 1) return filters.single;
  return {
    'compositeFilter': {'op': 'AND', 'filters': filters},
  };
}

String _restFieldPath(List<String> components) => components
    .map((component) => component.contains('.') ? '`$component`' : component)
    .join('.');

String _queryFieldPath(Object? rawField) => switch (rawField) {
      FieldPath path => _restFieldPath(path.components),
      FieldPathType.documentId => '__name__',
      String field => field,
      _ =>
        throw UnsupportedError('Unsupported Firestore field path: $rawField'),
    };

Map<String, dynamic> _encodeFieldFilter(
  Object? rawField,
  Object? rawOperator,
  Object? value,
) {
  final field = _queryFieldPath(rawField);
  final operator = rawOperator?.toString();
  final restOperator = switch (operator) {
    '==' => 'EQUAL',
    '!=' => 'NOT_EQUAL',
    '<' => 'LESS_THAN',
    '<=' => 'LESS_THAN_OR_EQUAL',
    '>' => 'GREATER_THAN',
    '>=' => 'GREATER_THAN_OR_EQUAL',
    'array-contains' => 'ARRAY_CONTAINS',
    'array-contains-any' => 'ARRAY_CONTAINS_ANY',
    'in' => 'IN',
    'not-in' => 'NOT_IN',
    _ =>
      throw UnsupportedError('Unsupported Firestore query operator: $operator'),
  };
  if (value == null && (operator == '==' || operator == '!=')) {
    return {
      'unaryFilter': {
        'field': {'fieldPath': field},
        'op': operator == '==' ? 'IS_NULL' : 'IS_NOT_NULL',
      },
    };
  }
  return {
    'fieldFilter': {
      'field': {'fieldPath': field},
      'op': restOperator,
      'value': _encodeValue(value),
    },
  };
}

Map<String, dynamic> _encodeFilterMap(Map<String?, Object?> filter) {
  final operator = filter['op']?.toString();
  final queries = filter['queries'];
  if ((operator == 'AND' || operator == 'OR') && queries is List) {
    return {
      'compositeFilter': {
        'op': operator,
        'filters': [
          for (final query in queries)
            if (query is Map) _encodeFilterMap(query.cast<String?, Object?>()),
        ],
      },
    };
  }
  return _encodeFieldFilter(
    filter['fieldPath'],
    filter['op'],
    filter['value'],
  );
}

List<Map<String, dynamic>> _encodeOrderBy(List<List<Object?>?> orderBy) => [
      for (final order in orderBy)
        if (order != null && order.isNotEmpty)
          {
            'field': {'fieldPath': _queryFieldPath(order[0])},
            'direction': order.length > 1 &&
                    order[1].toString().toLowerCase().contains('desc')
                ? 'DESCENDING'
                : 'ASCENDING',
          },
    ];

Map<String, dynamic> _encodeCursor(List<Object?> values,
        {required bool inclusive}) =>
    {
      'values': values.map(_encodeValue).toList(),
      'before': inclusive,
    };

class FirestorePigeonDecoder extends FirestoreMessageCodec {
  const FirestorePigeonDecoder(this.legacy);

  final bool legacy;

  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    // FieldPath uses a Firestore extension code which the public data codec
    // writes but intentionally leaves for its test-specific decoder to read.
    if (type == 192) {
      final count = readSize(buffer);
      final components = <String>[];
      for (var index = 0; index < count; index++) {
        components.add(readValue(buffer)! as String);
      }
      return FieldPath(components);
    }
    final isPigeonType =
        legacy ? type >= 128 && type <= 140 : type >= 129 && type <= 152;
    if (isPigeonType) {
      return PigeonWireValue(type, readValue(buffer));
    }
    return super.readValueOfType(type, buffer);
  }
}

PigeonWireValue _documentWire(
  String path,
  Map<dynamic, dynamic>? document,
) {
  final fields = document?['fields'];
  return PigeonWireValue(
    _legacyFirestorePigeon ? 134 : 141,
    <Object?>[
      path,
      fields is Map
          ? _decodeFields(fields.cast<Object?, Object?>())
          : <String?, Object?>{},
      _metadataPayload(hasPendingWrites: false, isFromCache: false),
    ],
  );
}

Object _metadataPayload({
  required bool hasPendingWrites,
  required bool isFromCache,
}) {
  final payload = <Object?>[hasPendingWrites, isFromCache];
  return _legacyFirestorePigeon ? payload : PigeonWireValue(140, payload);
}

_DocumentOption? _decodeDocumentOption(Object? value) {
  if (value is PigeonWireValue) value = value.value;
  if (value is List) {
    return _DocumentOption(
      value[0] as bool?,
      (value[1] as List?)?.cast<List<String?>?>(),
    );
  }
  if (value == null) return null;
  return _DocumentOption(
    (value as dynamic).merge as bool?,
    (value as dynamic).mergeFields as List<List<String?>?>?,
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
  final token = liveAuthIdTokenForApp(appName) ??
      liveAuthIdTokenForApp(defaultFirebaseAppName) ??
      Platform.environment['ENSEMBLE_TEST_FIREBASE_ID_TOKEN'];
  // Public Firestore reads work without a token. Private reads correctly return
  // Firestore's permission-denied response unless the test supplies a real ID
  // token or signs in through the app's real custom-token flow.
  return token ?? '';
}
