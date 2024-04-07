import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/firestore/firestore_types.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:flutter/widgets.dart';
import 'package:yaml/yaml.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirestoreAPIProvider extends APIProvider with LiveAPIProvider {
  FirebaseApp? _app;
  FirebaseFirestore get firestore => FirebaseFirestore.instanceFor(app: _app!);
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
  //we are evaluating ourselves recursively as the key can itself be dynamic and not just the value
  dynamic evaluate(dynamic original, DataContext eContext) {
    if (original == null) return null;
    if (original is Map) {
      Map<String, dynamic> processedMap = {};
      original.forEach((key, value) {
        var evaluatedKey = eContext.eval(key is String ? key : key.toString());
        processedMap[evaluatedKey] = evaluate(value, eContext);
      });
      return processedMap;
    } else if (original is List) {
      // Return the processed list directly for list elements
      return original.map((item) => evaluate(item, eContext)).toList();
    } else {
      // For scalar values or nulls
      return eContext.eval(original);
    }
  }


  Query getQuery(Map api) {
    String path = api['path'];
    CollectionReference collection =
        firestore.collection(path);
    Query query = collection;

    // Check if queries are provided and apply them
    Map? queryMap = api['query'];
    if (queryMap != null) {
      List? whereMap = queryMap['where'];
      if ( whereMap != null ) {
        for (var q in whereMap) {
          q.forEach((field, condition) {
            final operator = condition['operator'];
            final value = condition['value'];
            if (![
              'array-contains',
              'array-contains-any',
              'in',
              'not-in',
              '==',
              '!=',
              '>',
              '>=',
              '<',
              '<=',
              'isNull'
            ].contains(operator)) {
              throw ArgumentError('Unsupported operator: $operator');
            }
            switch (operator) {
              case 'array-contains':
                query = query.where(field, arrayContains: value);
                break;
              case 'array-contains-any':
                query = query.where(field, arrayContainsAny: value);
                break;
              case 'in':
                query = query.where(field, whereIn: value);
                break;
              case 'not-in':
                query = query.where(field, whereNotIn: value);
                break;
              case '==':
                query = query.where(field, isEqualTo: value);
                break;
              case '!=':
                query = query.where(field, isNotEqualTo: value);
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
      // Apply 'orderBy' clauses
      if (queryMap.containsKey('orderBy')) {
        List orderByClauses = queryMap['orderBy'];
        for (var order in orderByClauses) {
          // Check if the orderBy clause is a string or a map
          if (order is String) {
            // If it's a string, orderBy this field in ascending order by default
            query = query.orderBy(order);
          } else if (order is Map) {
            // If it's a map, extract the field and descending flag
            String field = order.keys.first;
            bool descending = order[field]['descending'] ?? false;
            query = query.orderBy(field, descending: descending);
          }
        }
      }
      // Apply limit if present
      if (queryMap.containsKey('limit')) {
        query = query.limit(queryMap['limit']);
      }

      // Apply pagination constraints if present
      if (queryMap.containsKey('startAfter')) {
        query = query.startAfter(queryMap['startAfter']);
      }
      if (queryMap.containsKey('startAt')) {
        query = query.startAt(queryMap['startAt']);
      }
      if (queryMap.containsKey('endBefore')) {
        query = query.endBefore(queryMap['endBefore']);
      }
      if (queryMap.containsKey('endAt')) {
        query = query.endAt(queryMap['endAt']);
      }
      // Apply limitToLast if present
      if (queryMap.containsKey('limitToLast')) {
        query = query.limitToLast(queryMap['limitToLast']);
      }
    }
    return query;
  }
  Future<QuerySnapshot> performGetOperation(Map evaluatedApi) async {
    Query query = getQuery(evaluatedApi);
    return await query.get();
  }

  Future<DocumentReference> performAddOperation(Map evaluatedApi) async {
    String path = evaluatedApi['path'];
    Map<String, dynamic> data = evaluatedApi['data'];
    CollectionReference collection = firestore.collection(path);
    return await collection.add(data);
  }

  Future<void> performSetOperation(Map evaluatedApi) async {
    String path = evaluatedApi['path'];
    Map<String, dynamic> data = evaluatedApi['data'];
    DocumentReference docRef = firestore.doc(path);
    return await docRef.set(data);
  }

  Future<void> performUpdateOperation(Map evaluatedApi) async {
    String path = evaluatedApi['path'];
    Map<String, dynamic> data = evaluatedApi['data'];
    DocumentReference docRef = firestore.doc(path);
    return await docRef.update(data);
  }

  Future<void> performDeleteOperation(Map evaluatedApi) async {
    String path = evaluatedApi['path'];
    DocumentReference docRef = firestore.doc(path);
    return await docRef.delete();
  }

  @override
  Future<FirestoreResponse> invokeApi(BuildContext context, YamlMap apiMap, DataContext eContext, String apiName) async {
    if (_app == null) {
      throw ArgumentError('Firebase app not initialized');
    }
    Map api = evaluate(apiMap, eContext);
    try {
      final operation = evaluate(api['operation'], eContext) ?? 'get'; // Default to 'get'

      switch (operation) {
        case 'get':
          final QuerySnapshot snapshot = await performGetOperation(api);
          return getOKResponse(apiName, snapshot);
        case 'add':
          final DocumentReference docRef = await performAddOperation(api);
          return getOKResponse(apiName, docRef);
        case 'set':
          await performSetOperation(api);
          break;
        case 'update':
          await performUpdateOperation(api);
          break;
        case 'delete':
          await performDeleteOperation(api);
          break;
        default:
          throw UnimplementedError('$operation is not supported in this context.');
      }

      // For operations that don't inherently return a result (set, update, delete), return a success message
      return FirestoreResponse(
        apiState: APIState.success,
        body: {'message': 'Operation completed successfully'},
        apiName: apiName,
        isOkay: true,
      );
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

  FirestoreResponse getOKResponse(String apiName, dynamic result) {
    var body;

    if (result is QuerySnapshot) {
      // Handle QuerySnapshot for 'get' operations
      body = {'documents': getDocuments(result)};
    } else if (result is DocumentReference) {
      // Handle DocumentReference for 'add' operations
      body = {'id': result.id, 'path': result.path};
    } else if (result == null) {
      // Handle void results for 'set', 'update', and 'delete' operations
      body = {'message': 'Operation completed successfully'};
    } else {
      // Fallback for unexpected types, you might not need this, but it's here just in case
      body = {'message': 'Unknown response type', 'details': result.toString()};
    }

    return FirestoreResponse(
      apiState: APIState.success,
      body: body,
      apiName: apiName,
      isOkay: true,
    );
  }


  List<Map<String, dynamic>> getDocuments(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      // Create a new map from the document data
      Map<String, dynamic> data = convertFirestoreTypes(doc.data() as Map<String, dynamic>);
      // Add the document ID under a reserved/special key
      data['_documentId'] = doc.id;
      return data;
    }).toList();
  }

  Map<String, dynamic> convertFirestoreTypes(Map<String, dynamic> input) {
    Map<String, dynamic> convert(Map<String, dynamic> map) {
      final Map<String, dynamic> newMap = {};
      map.forEach((key, value) {
        if (value is GeoPoint) {
          // Convert GeoPoint to FirestoreGeoPoint
          newMap[key] = FirestoreGeoPoint(value);
        } else if (value is Timestamp) {
          // Convert Timestamp to FirestoreTimestamp
          newMap[key] = FirestoreTimestamp(value);
        } else if (value is DocumentReference) {
          // Convert DocumentReference to FirestoreReference
          newMap[key] = FirestoreDocumentReference(value);
        } else if (value is CollectionReference ) {
          // Convert CollectionReference to FirestoreCollectionReference
          newMap[key] = FirestoreCollectionReference(value);
        } else if (value is Map<String, dynamic>) {
          // Recursively convert nested maps
          newMap[key] = convert(value);
        } else if (value is List) {
          // Convert lists, handling nested maps within them
          newMap[key] = value.map((item) {
            if (item is Map<String, dynamic>) {
              return convert(item); // Recursively convert nested maps in lists
            } else if (item is GeoPoint) {
              return FirestoreGeoPoint(item); // Convert GeoPoint in lists
            } else if (item is Timestamp) {
              return FirestoreTimestamp(item); // Convert Timestamp in lists
            } else if (item is DocumentReference) {
              // Convert DocumentReference to FirestoreReference
              return FirestoreDocumentReference(item);
            } else if ( item is CollectionReference ) {
              // Convert CollectionReference to FirestoreCollectionReference
              return FirestoreCollectionReference(item);
            } else {
              return item; // Return the item unchanged if it's not a Map, GeoPoint, or Timestamp
            }
          }).toList();
        } else {
          // For all other types, just copy the value
          newMap[key] = value;
        }
      });
      return newMap;
    }

    return convert(input); // Start the conversion with the input map
  }

  @override
  Future<Response> invokeMockAPI(DataContext eContext, mock) {
    // TODO: implement invokeMockAPI
    throw UnimplementedError();
  }

  @override
  Future<FirestoreResponse> subscribeToApi(BuildContext context, YamlMap apiMap,
      DataContext eContext, String apiName, ResponseListener listener) async {
    if (_app == null) {
      throw ArgumentError('Firebase app not initialized');
    }
    Map api = evaluate(apiMap, eContext);
    final operation =
        eContext.eval(api['operation']) ?? 'get'; // Default to 'get'
    if (operation != 'get') {
      // Handle set, update, delete accordingly
      throw UnimplementedError('$operation is not supported in this context.');
    }
    Query query = getQuery(api);
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
    } catch (e) {
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
