import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/widgets.dart';
import 'package:yaml/yaml.dart';
import 'dart:math' show asin, cos, pi, sin, sqrt;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class FirestoreAPIProvider extends APIProvider with LiveAPIProvider {
  FirebaseApp? _app;
  List<StreamSubscription<QuerySnapshot>> _subscriptions = [];

  @override
  Future<void> init(String appId, Map<String, dynamic> config) async {
    FirebaseConfig firebaseConfig = FirebaseConfig.fromMap(config);

    // Function to compare FirebaseOptions
    bool areOptionsEqual(FirebaseOptions a, FirebaseOptions b) {
      return a.apiKey == b.apiKey &&
          a.appId == b.appId &&
          a.messagingSenderId == b.messagingSenderId &&
          a.projectId == b.projectId &&
          a.authDomain == b.authDomain &&
          a.storageBucket == b.storageBucket &&
          a.measurementId == b.measurementId;
    }
    FirebaseOptions? platformOptions;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      platformOptions = firebaseConfig.iOSConfig;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      platformOptions = firebaseConfig.androidConfig;
    } else if (kIsWeb) {
      platformOptions = firebaseConfig.webConfig;
    }

    if (platformOptions == null) {
      throw ArgumentError('Platform-specific Firebase configuration not found');
    }

    // Check for an already initialized app with the same options
    FirebaseApp? existingApp = Firebase.apps.firstWhereOrNull(
          (app) => areOptionsEqual(app.options, platformOptions!),
    );

    if (existingApp != null) {
      // App with the same options is already initialized
      print('Using existing Firebase app: ${existingApp.name}');
      _app = existingApp;
    } else {
      // Initialize the new Firebase app with the options
      FirebaseApp app = await Firebase.initializeApp(
        name: appId,
        options: platformOptions,
      );
      print('Initialized new Firebase app: ${app.name}');
      _app = app;
    }
  }

  Query getQuery(BuildContext context,
      YamlMap api,
      DataContext eContext) {
    String path = eContext.eval(api['path']);
    CollectionReference collection = FirebaseFirestore.instanceFor(app: _app!)
        .collection(path);
    Query query = collection;

    // Check if queries are provided and apply them
    if (api.containsKey('queries') && api['queries'] != null) {
      for (var q in api['queries']) {
        q.forEach((field, condition) {
          final operator = eContext.eval(condition['operator']);
          final value = eContext.eval(condition['value']);
          if (![
            'arrayContains',
            'arrayContainsAny',
            'whereIn',
            'whereNotIn',
            'isEqualTo',
            '>',
            '>=',
            '<',
            '<=',
            'isNull'
          ].contains(operator)) {
            throw ArgumentError('Unsupported operator: $operator');
          }
          switch (operator) {
            case 'arrayContains':
              query = query.where(field, arrayContains: value);
              break;
            case 'arrayContainsAny':
              query = query.where(field, arrayContainsAny: value);
              break;
            case 'whereIn':
              query = query.where(field, whereIn: value);
              break;
            case 'whereNotIn':
              query = query.where(field, whereNotIn: value);
              break;
            case '==':
              query = query.where(field, isEqualTo: value);
              break;
            case '>':
              query = query.where(field, isGreaterThan: value);
              break;
            case '>=':
              query = query.where(field, isGreaterThanOrEqualTo: value);
              break;
            case '<':
              query = query.where(field, isLessThan: value);
              break;
            case '<=':
              query = query.where(field, isLessThanOrEqualTo: value);
              break;
            case 'isNull':
              query = query.where(field, isNull: value);
              break;
          // Add more operators if needed
            default:
              throw ArgumentError('Unsupported operator: $operator');
          }
        });
      }
    }
    return query;
  }

  @override
  Future<FirestoreResponse> invokeApi(BuildContext context,
      YamlMap api,
      DataContext eContext,
      String apiName) async {
    if (_app == null) {
      throw ArgumentError('Firebase app not initialized');
    }
    try {
      final operation = eContext.eval(api['operation']) ??
          'get'; // Default to 'get'
      if (operation != 'get') {
        // Handle set, update, delete accordingly
        throw UnimplementedError(
            '$operation is not supported in this context.');
      }
      Query query = getQuery(context, api, eContext);
      // Execute the query and handle the response
      final QuerySnapshot snapshot = await query.get();
      return getOKResponse(apiName, snapshot);
    } catch (e) {
      return getErrorResponse(apiName, e);
    }
  }

  FirestoreResponse getErrorResponse(String apiName, e) {
    return FirestoreResponse(
      apiState: APIState.error,
      body: e.toString(),
      apiName: apiName,
      isOkay: false,
    );
  }

  FirestoreResponse getOKResponse(String apiName, QuerySnapshot snapshot) {
    return FirestoreResponse(
      apiState: APIState.success,
      body: {'documents': getDocuments(snapshot)},
      apiName: apiName,
      isOkay: true,
    );
  }

  List<Map<String, dynamic>> getDocuments(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      // Create a new map from the document data
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      // Add the document ID under a reserved/special key
      data['_documentId'] = doc.id;
      return data;
    }).toList();
  }

  @override
  Future<Response> invokeMockAPI(DataContext eContext, mock) {
    // TODO: implement invokeMockAPI
    throw UnimplementedError();
  }

  @override
  Future<FirestoreResponse> subscribeToApi(BuildContext context,
      YamlMap api, DataContext eContext,
      String apiName, ResponseListener listener) async {
    if (_app == null) {
      throw ArgumentError('Firebase app not initialized');
    }
    final operation = eContext.eval(api['operation']) ??
        'get'; // Default to 'get'
    if (operation != 'get') {
      // Handle set, update, delete accordingly
      throw UnimplementedError(
          '$operation is not supported in this context.');
    }
    Query query = getQuery(context, api, eContext);
    _subscriptions.add(query.snapshots().listen((QuerySnapshot snapshot) {
      listener.call(getOKResponse(apiName, snapshot));
    }));
    return FirestoreResponse(
      apiState: APIState.success,
      body: 'Subscribed to API',
      apiName: apiName,
      isOkay: true,
    );
  }

  @override
  dispose() {
    try {
      if (_subscriptions.isNotEmpty) {
        for (var subscription in _subscriptions) {
          subscription.cancel();
        }
      }
      _subscriptions = [];
    } catch(e) {
      print('Error disposing FirestoreAPIProvider: $e');
    }
  }

  @override
  APIProvider clone() {
    FirestoreAPIProvider provider = FirestoreAPIProvider();
    provider._app = _app;
    return provider;
  }
}

class FirestoreResponse extends Response {
  FirestoreResponse({
    APIState apiState = APIState.idle,
    dynamic body,
    String apiName = '',
    bool isOkay = true,
  }) {
    super.apiState = apiState;
    super.body = body;
    super.apiName = apiName;
    super.isOkay = isOkay;
  }
}

class FirestoreGeoPoint with Invokable {
  final GeoPoint geoPoint;

  FirestoreGeoPoint(this.geoPoint);

  @override
  Map<String, Function> getters() {
  return {
  'latitude': () => geoPoint.latitude,
  'longitude': () => geoPoint.longitude,
  };
  }

  // As GeoPoint is immutable, we provide an empty map for setters.
  @override
  Map<String, Function> setters() => {};

  // Implementing a simple distanceTo method as an example.
  @override
  Map<String, Function> methods() {
  return {
  'distanceTo': (FirestoreGeoPoint other) {
  const double earthRadiusKm = 6371;
  double dLat = _degreesToRadians(other.geoPoint.latitude - geoPoint.latitude);
  double dLon = _degreesToRadians(other.geoPoint.longitude - geoPoint.longitude);
  double lat1 = _degreesToRadians(geoPoint.latitude);
  double lat2 = _degreesToRadians(other.geoPoint.latitude);

  double a = sin(dLat/2) * sin(dLat/2) +
  sin(dLon/2) * sin(dLon/2) * cos(lat1) * cos(lat2);
  double c = 2 * asin(sqrt(a));
  return earthRadiusKm * c;
  },
  };
  }

  double _degreesToRadians(double degrees) {
  return degrees * pi / 180;
  }
  }
  class FirestoreTimestamp with Invokable {
  final Timestamp timestamp;

  FirestoreTimestamp(this.timestamp);

  @override
  Map<String, Function> getters() {
  return {
  'seconds': () => timestamp.seconds,
  'nanoseconds': () => timestamp.nanoseconds,
  'toDate': () => timestamp.toDate(),
  };
  }

  @override
  Map<String, Function> setters() => {};

  @override
  Map<String, Function> methods() => {};
  }


