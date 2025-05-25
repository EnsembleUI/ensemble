import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:cloud_functions/cloud_functions.dart';
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
  
  // Static variables to track initialization
  static bool _firebaseInitialized = false;
  static bool _appCheckInitialized = false;
  static bool _initializationInProgress = false;

  /// Check if Firebase Functions API provider is enabled
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
      List<String> providers = apiProviders.split(',').map((e) => e.trim().toLowerCase()).toList();
      bool isEnabled = providers.contains('firebase');
      
      log('API Providers: $apiProviders, Firebase enabled: $isEnabled');
      return isEnabled;
    } catch (e) {
      log('Error checking Firebase provider status: $e');
      return false;
    }
  }

  /// Initialize Firebase if not already initialized
  static Future<void> _initializeFirebase() async {
    if (_firebaseInitialized) {
      log('Firebase already initialized');
      return;
    }

    try {
      log('Initializing Firebase...');
      
      // Check if Firebase is already initialized externally
      if (Firebase.apps.isNotEmpty) {
        _firebaseInitialized = true;
        log('Firebase was already initialized externally');
        return;
      }

      // Get Firebase options from config
      FirebaseOptions? firebaseOptions = await _getFirebaseOptions();
      
      if (firebaseOptions != null) {
        await Firebase.initializeApp(options: firebaseOptions);
        _firebaseInitialized = true;
        log('Firebase initialized successfully with config options');
      } else {
        await Firebase.initializeApp();
        _firebaseInitialized = true;
        log('Firebase initialized using default config files');
      }
    } catch (e) {
      log('Failed to initialize Firebase: $e');
      throw RuntimeError('Firebase initialization failed: $e');
    }
  }

static Future<FirebaseOptions?> _getFirebaseOptions() async {
  try {
    log('Reading Firebase config from environment variables...');
    
    // Get config from Ensemble environment variables
    EnsembleConfig? ensembleConfig = Ensemble().getConfig();
    if (ensembleConfig == null) {
      log('Ensemble config is not available, using default Firebase initialization');
      return null;
    }
    
    UserAppConfig? appConfig = ensembleConfig.definitionProvider.getAppConfig();
    if (appConfig == null) {
      log('App config is not available, using default Firebase initialization');
      return null;
    }
    
    // Get the firebase_config from environment variables
    String? firestoreConfigStr = appConfig.envVariables?['firebase_config'];
    if (firestoreConfigStr == null || firestoreConfigStr.isEmpty) {
      log('firebase_config environment variable not found, using default Firebase initialization');
      return null;
    }
    
    // Parse the JSON string
    Map<String, dynamic> firebaseConfig;
    try {
      firebaseConfig = jsonDecode(firestoreConfigStr);
      log('Successfully parsed firebase_config JSON');
    } catch (e) {
      log('Failed to parse firebase_config JSON: $e, using default Firebase initialization');
      return null;
    }

    // Create a FirebaseConfig-like structure based on platform
    FirebaseOptions? platformOptions;
    
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Get iOS configuration from config
      var iosConfig = firebaseConfig['ios'];
      if (iosConfig != null) {
        log('Using iOS Firebase configuration');
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
        log('Using Android Firebase configuration');
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
        log('Using Web Firebase configuration');
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
    
    if (platformOptions != null) {
      log('Firebase options loaded successfully for current platform');
    } else {
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
      log('Firebase App Check already initialized or initialization in progress');
      return;
    }

    _initializationInProgress = true;

    try {
      log('Initializing Firebase App Check...');

      if (!_firebaseInitialized) {
        log('Firebase not initialized, initializing Firebase first for App Check...');
        await _initializeFirebase();
      }

      // Now initialize App Check
      if (kDebugMode) {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
        log('Firebase App Check initialized with debug providers');
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
        log('Firebase App Check initialized with production providers');
      }

      _appCheckInitialized = true;
      log('Firebase App Check initialized successfully');
    } catch (e) {
      log('Failed to initialize Firebase App Check: $e');

      // Always continue without App Check if it fails
      log('Continuing without App Check due to initialization failure');
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
        {'error': 'Firebase Functions API provider is not enabled. Please set cloud_function_provider environment variable to include "firebase"'},
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
    log('Using region: $region for function: $name');

    // Check if Firebase is initialized, if not initialize it
    if (!_firebaseInitialized) {
      try {
        log('Firebase not initialized, initializing now...');
        await _initializeFirebase();
        
        log('Firebase initialized successfully');
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
      functionsInstance = FirebaseFunctions.instanceFor(region: region);
      log('Created Firebase Functions instance for region: $region');
    } catch (e) {
      log('Failed to create Firebase Functions instance: $e');
      return FirebaseFunctionResponse(
        {'error': 'Failed to create Firebase Functions instance: ${e.toString()}'},
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
      log('Calling Firebase Function: $name with data: ${jsonEncode(data)}');
      
      HttpsCallable callable = functionsInstance.httpsCallable(name);
      HttpsCallableResult result = await callable.call(data);

      log('Firebase Function $name executed successfully');

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
      errorMessage = 'Firebase Functions error: ${error.message}. Details: ${error.details}';
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
  dispose() {
  }
}

/// A wrapper class for Firebase Function responses
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