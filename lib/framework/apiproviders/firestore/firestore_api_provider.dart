import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/firestore/firestore_app.dart';
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
  late FirestoreApp firestoreApp;

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
    firestoreApp = FirestoreApp(firestore);
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
          final dynamic snapshot = await firestoreApp.performGetOperation(api);
          return getOKResponse(apiName, snapshot);
        case 'add':
          final DocumentReference docRef = await firestoreApp.performAddOperation(api);
          return getOKResponse(apiName, docRef);
        case 'set':
          await firestoreApp.performSetOperation(api);
          break;
        case 'update':
          await firestoreApp.performUpdateOperation(api);
          break;
        case 'delete':
          await firestoreApp.performDeleteOperation(api);
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
    Query query = firestoreApp.getQuery(api);
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
    provider.firestoreApp = firestoreApp;
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
