import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:yaml/yaml.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

class FirebaseFunctionsAPIProvider extends APIProvider {
  String _defaultRegion = 'us-central1';
  static late FirebaseApp _app;

  // Static variables to track initialization
  static bool _firebaseInitialized = false;
  static bool _appCheckInitialized = false;
  static bool _initializationInProgress = false;

  static get platformOptions => null;

  // Check if Firebase Functions API provider is enabled
  bool _isFirebaseProviderEnabled() {
    try {
      EnsembleConfig? config = Ensemble().getConfig();
      if (config == null) {
        log('Ensemble config is not initialized');
        return false;
      }

      UserAppConfig? appConfig = config.definitionProvider.getAppConfig();
      if (appConfig == null) {
        log('App config is not available');
        return false;
      }

      String? apiProviders = appConfig.envVariables?['cloud_function_provider'];
      if (apiProviders == null) {
        log('cloud_function_provider environment variable is not set');
        return false;
      }

      // Check if firebase is enabled (can be 'firebase' or comma-separated list containing 'firebase')
      List<String> providers =
          apiProviders.split(',').map((e) => e.trim().toLowerCase()).toList();
      bool isEnabled = providers.contains('firebase');

      return isEnabled;
    } catch (e) {
      log('Error checking Firebase provider status: $e');
      return false;
    }
  }

  /// Initialize Firebase if not already initialized
  static Future<void> _initializeFirebase() async {
    bool areOptionsEqual(FirebaseOptions a, FirebaseOptions b) {
      return a.apiKey == b.apiKey &&
          a.appId == b.appId &&
          a.messagingSenderId == b.messagingSenderId &&
          a.projectId == b.projectId &&
          a.authDomain == b.authDomain &&
          a.storageBucket == b.storageBucket &&
          a.measurementId == b.measurementId;
    }

    if (_firebaseInitialized) {
      return;
    }

    try {
      FirebaseOptions? firebaseOptions = await _getFirebaseOptions();
      FirebaseApp? existingApp = Firebase.apps.firstWhereOrNull(
        (app) => areOptionsEqual(app.options, firebaseOptions!),
      );

      if (existingApp != null) {
        // App with the same options is already initialized
        _firebaseInitialized = true;

        _app = existingApp;
      } else {
        // Initialize the new Firebase app with the options
        _firebaseInitialized = true;
        FirebaseApp app = await Firebase.initializeApp(
          options: firebaseOptions,
        );
        _app = app;
      }
    } catch (e) {
      log('Failed to initialize Firebase: $e');
      throw RuntimeError('Firebase initialization failed: $e');
    }
  }

  static Future<FirebaseOptions?> _getFirebaseOptions() async {
    try {
      // Get config from Ensemble environment variables
      EnsembleConfig? ensembleConfig = Ensemble().getConfig();
      if (ensembleConfig == null) {
        log('Ensemble config is not available');
        return null;
      }

      UserAppConfig? appConfig =
          ensembleConfig.definitionProvider.getAppConfig();
      if (appConfig == null) {
        log('App config is not available');
        return null;
      }

      // Get the firebase_config from environment variables
      String? firebaseConfigStr = appConfig.envVariables?['firebase_config'] ??
          appConfig.envVariables?['firestore_config'];
      if (firebaseConfigStr == null || firebaseConfigStr.isEmpty) {
        log('firebase_config environment variable not found');
        return null;
      }

      // Parse the JSON string
      Map<String, dynamic> firebaseConfig;
      try {
        firebaseConfig = jsonDecode(firebaseConfigStr);
      } catch (e) {
        log('Failed to parse firebase_config JSON: $e');
        return null;
      }

      // Create a FirebaseConfig-like structure based on platform
      FirebaseOptions? platformOptions;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Get iOS configuration from config
        var iosConfig = firebaseConfig['ios'];
        if (iosConfig != null) {
          platformOptions = FirebaseOptions(
            apiKey: iosConfig['apiKey'],
            appId: iosConfig['appId'],
            messagingSenderId: iosConfig['messagingSenderId'],
            projectId: iosConfig['projectId'],
          );
        } else {
          log('iOS configuration not found in firebase_config');
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // Get Android configuration from config
        var androidConfig = firebaseConfig['android'];
        if (androidConfig != null) {
          platformOptions = FirebaseOptions(
            apiKey: androidConfig['apiKey'],
            appId: androidConfig['appId'],
            messagingSenderId: androidConfig['messagingSenderId'],
            projectId: androidConfig['projectId'],
          );
        } else {
          log('Android configuration not found in firebase_config');
        }
      } else if (kIsWeb) {
        // Get Web configuration from config
        var webConfig = firebaseConfig['web'];
        if (webConfig != null) {
          platformOptions = FirebaseOptions(
            apiKey: webConfig['apiKey'],
            appId: webConfig['appId'],
            messagingSenderId: webConfig['messagingSenderId'],
            projectId: webConfig['projectId'],
          );
        } else {
          log('Web configuration not found in firebase_config');
        }
      }

      if (platformOptions == null) {
        log('No valid Firebase configuration found for current platform');
      }

      return platformOptions;
    } catch (e) {
      log('Error getting Firebase options: $e');
      return null;
    }
  }

  /// Initialize Firebase App Check with Firebase dependency check
  static Future<void> initializeFirebaseAppCheck() async {
    if (_appCheckInitialized || _initializationInProgress) {
      return;
    }

    _initializationInProgress = true;

    try {
      if (!_firebaseInitialized) {
        await _initializeFirebase();
      }
      FirebaseAppCheck appCheck = FirebaseAppCheck.instanceFor(app: _app);

      // Now initialize App Check
      if (kDebugMode) {
        await appCheck.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
      } else {
        await appCheck.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
      }

      _appCheckInitialized = true;
    } catch (e) {
      log('Failed to initialize Firebase App Check: $e');

      // Always continue without App Check if it fails
      _appCheckInitialized = false;

      // Don't rethrow to prevent blocking the app
    } finally {
      _initializationInProgress = false;
    }
  }

  @override
  Future<void> init(String appId, Map<String, dynamic> config) async {
    // This doesn't require initialization
  }

  @override
  Future<Response> invokeApi(BuildContext context, YamlMap api,
      DataContext eContext, String apiName) async {
    // Check if Firebase provider is enabled in environment variables
    if (!_isFirebaseProviderEnabled()) {
      return FirebaseFunctionResponse(
        {
          'error':
              'Firebase Functions API provider is not enabled. Please set cloud_function_provider environment variable to include "firebase"'
        },
        {'Content-Type': 'application/json'},
        400,
        'Bad Request',
        APIState.error,
        apiName: apiName,
      );
    }

    // Extract the function name from the API definition
    String name = eContext.eval(api['name'] ?? '')?.toString() ?? '';
    if (name.isEmpty) {
      return FirebaseFunctionResponse(
        {'error': 'Function name cannot be empty'},
        {'Content-Type': 'application/json'},
        400,
        'Bad Request',
        APIState.error,
        apiName: apiName,
      );
    }

    // Get region from API definition, fallback to default
    String? apiRegion = eContext.eval(api['region'])?.toString();
    String region = apiRegion?.isNotEmpty == true ? apiRegion! : _defaultRegion;

    // Check if Firebase is initialized, if not initialize it
    if (!_firebaseInitialized) {
      try {
        await _initializeFirebase();
      } catch (e) {
        log('Failed to initialize Firebase: $e');
        return FirebaseFunctionResponse(
          {'error': 'Failed to initialize Firebase: ${e.toString()}'},
          {'Content-Type': 'application/json'},
          500,
          'Internal Server Error',
          APIState.error,
          apiName: apiName,
        );
      }
    }

    // Create Functions instance for the specified region
    FirebaseFunctions functionsInstance;
    try {
      functionsInstance =
          FirebaseFunctions.instanceFor(app: _app, region: region);
    } catch (e) {
      log('Failed to create Firebase Functions instance: $e');
      return FirebaseFunctionResponse(
        {
          'error':
              'Failed to create Firebase Functions instance: ${e.toString()}'
        },
        {'Content-Type': 'application/json'},
        500,
        'Internal Server Error',
        APIState.error,
        apiName: apiName,
      );
    }

    // Prepare data payload for the function
    Map<String, dynamic> data = {};
    if (api['data'] is YamlMap) {
      api['data'].forEach((key, value) {
        data[key.toString()] = eContext.eval(value);
      });
    } else if (api['body'] is YamlMap) {
      // Support for 'body' parameter for consistency with HTTP provider
      api['body'].forEach((key, value) {
        data[key.toString()] = eContext.eval(value);
      });
    }

    try {
      HttpsCallable callable = functionsInstance.httpsCallable(name);
      HttpsCallableResult result = await callable.call(data);

      // Process response
      return FirebaseFunctionResponse(
        result.data,
        {'Content-Type': 'application/json'},
        200,
        'OK',
        APIState.success,
        apiName: apiName,
      );
    } catch (e) {
      log('Error calling Firebase Function $name: $e');
      return _handleError(e, apiName);
    }
  }

  FirebaseFunctionResponse _handleError(Object error, String apiName) {
    String errorMessage;
    int statusCode = 500;

    if (error is FirebaseFunctionsException) {
      statusCode = error.code as int;
      errorMessage =
          'Firebase Functions error: ${error.message}. Details: ${error.details}';
    } else {
      errorMessage = 'Unexpected error: ${error.toString()}.';
    }

    log(errorMessage);
    return FirebaseFunctionResponse(
      {'error': errorMessage},
      {'Content-Type': 'application/json'},
      statusCode,
      'Error',
      APIState.error,
      apiName: apiName,
    );
  }

  @override
  Future<Response> invokeMockAPI(DataContext eContext, dynamic mock) async {
    if (mock is Map) {
      mock = YamlMap.wrap(mock);
    }
    dynamic mockResponse = eContext.eval(mock);
    return FirebaseFunctionResponse(
      mockResponse['body'] ?? mockResponse,
      mockResponse['headers'] ?? {'Content-Type': 'application/json'},
      mockResponse['statusCode'] ?? 200,
      mockResponse['reasonPhrase'] ?? 'OK',
      APIState.success,
    );
  }

  @override
  FirebaseFunctionsAPIProvider clone() {
    return FirebaseFunctionsAPIProvider();
  }

  @override
  dispose() {}
}

// A wrapper class for Firebase Function responses
class FirebaseFunctionResponse extends Response {
  FirebaseFunctionResponse(
    dynamic body,
    Map<String, dynamic>? headers,
    int? statusCode,
    String? reasonPhrase,
    APIState apiState, {
    String apiName = '',
  }) {
    super.body = body;
    super.headers = headers;
    super.statusCode = statusCode;
    super.reasonPhrase = reasonPhrase;
    super.apiState = apiState;
    super.apiName = apiName;
    super.isOkay = statusCode != null && statusCode >= 200 && statusCode <= 299;
  }

  FirebaseFunctionResponse.updateState({required APIState apiState}) {
    super.updateState(apiState: apiState);
  }

  @override
  Map<String, String> get cookies => {}; // Firebase Functions don't use cookies
}
