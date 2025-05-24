import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/util/utils.dart';
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

  /// Check if Firebase is currently initialized
  bool isFirebaseInitialized() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

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

  /// Check if Firebase App Check should be enabled
  static bool _isAppCheckEnabled() {
    try {
      EnsembleConfig? config = Ensemble().getConfig();
      if (config == null) {
        log('Ensemble config is not initialized for App Check check');
        return false;
      }
      
      UserAppConfig? appConfig = config.definitionProvider.getAppConfig();
      if (appConfig == null) {
        log('App config is not available for App Check check');
        return false;
      }
      
      String? appCheckEnabled = appConfig.envVariables?['firebase_app_check'];
      if (appCheckEnabled == null) {
        log('firebase_app_check environment variable is not set, defaulting to false');
        return false;
      }
      
      // Check if appcheck is enabled (true/false or yes/no)
      bool isEnabled = appCheckEnabled.toLowerCase() == 'true' || 
                      appCheckEnabled.toLowerCase() == 'yes' || 
                      appCheckEnabled.toLowerCase() == '1';
      
      log('Firebase App Check: $appCheckEnabled, Enabled: $isEnabled');
      return isEnabled;
    } catch (e) {
      log('Error checking Firebase App Check status: $e');
      return false;
    }
  }

  /// Initialize Firebase if not already initialized
  static Future<void> _initializeFirebase([Map<String, dynamic>? config]) async {
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
      FirebaseOptions? firebaseOptions = await _getFirebaseOptions(config);
      
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

  /// Get Firebase options from config map (similar to Firestore approach)
  static Future<FirebaseOptions?> _getFirebaseOptions(Map<String, dynamic>? config) async {
    try {
      if (config == null) {
        log('No config provided, using default Firebase initialization');
        return null;
      }

      // Create a FirebaseConfig-like structure
      FirebaseOptions? platformOptions;
      
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Get iOS configuration from config
        var iosConfig = config['ios'];
        if (iosConfig != null) {
          platformOptions = FirebaseOptions(
            apiKey: iosConfig['apiKey'],
            appId: iosConfig['appId'],
            messagingSenderId: iosConfig['messagingSenderId'],
            projectId: iosConfig['projectId'],
          );
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // Get Android configuration from config
        var androidConfig = config['android'];
        if (androidConfig != null) {
          platformOptions = FirebaseOptions(
            apiKey: androidConfig['apiKey'],
            appId: androidConfig['appId'],
            messagingSenderId: androidConfig['messagingSenderId'],
            projectId: androidConfig['projectId'],
          );
        }
      } else if (kIsWeb) {
        // Get Web configuration from config
        var webConfig = config['web'];
        if (webConfig != null) {
          platformOptions = FirebaseOptions(
            apiKey: webConfig['apiKey'],
            appId: webConfig['appId'],
            messagingSenderId: webConfig['messagingSenderId'],
            projectId: webConfig['projectId'],
            authDomain: webConfig['authDomain'],
            storageBucket: webConfig['storageBucket'],
            measurementId: webConfig['measurementId'],
          );
        }
      }

      // Fallback to hardcoded values if no config found
      if (platformOptions == null) {
        if (Platform.isAndroid) {
          platformOptions = const FirebaseOptions(
            apiKey: "AIzaSyD9a8iVJ4LSz8lpp4GUmzxxxtmtQsX3C80",
            appId: "1:49232071130:android:95c22ce11d6de7c114d8e3",
            messagingSenderId: "49232071130",
            projectId: "noumantest-12630",
          );
        } else if (Platform.isIOS) {
          platformOptions = const FirebaseOptions(
            apiKey: "AIzaSyCdj73RKpJNGB19XTNmLKg_YTb9aThNhAc",
            appId: "1:49232071130:ios:3ded2134a088d83514d8e3",
            messagingSenderId: "49232071130",
            projectId: "noumantest-12630",
          );
        }
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

      // Ensure Firebase is initialized before App Check
      bool firebaseReady = false;
      try {
        firebaseReady = Firebase.apps.isNotEmpty;
      } catch (e) {
        firebaseReady = false;
      }

      if (!firebaseReady) {
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
    log('Initializing Firebase Functions API Provider...');
    
    // Check if Firebase provider is enabled
    if (!_isFirebaseProviderEnabled()) {
      throw RuntimeError('Firebase Functions API provider is not enabled. Please set cloud_function_provider environment variable to include "firebase"');
    }

    // Initialize Firebase if not already done (pass config for Firebase options)
    await _initializeFirebase(config);



    // Handle emulator configuration
    bool useEmulator = Utils.getBool(config['useEmulator'], fallback: false);
    if (useEmulator) {
      String emulatorHost = config['emulatorHost'] ?? 'localhost';
      int emulatorPort = config['emulatorPort'] ?? 5001;
      
      // Note: Emulator configuration will be applied when Functions instance is created per API call
      log('Emulator configuration: $emulatorHost:$emulatorPort (will be applied per API call)');
    }

    log('Firebase Functions API Provider initialized successfully');
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
    if (!isFirebaseInitialized()) {
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
    // Nothing specific to dispose
  }

  /// Get the initialization status
  static bool get isFirebaseInitializedStatic => _firebaseInitialized;
  static bool get isAppCheckInitialized => _appCheckInitialized;

  /// Reset initialization status (useful for testing)
  static void resetInitialization() {
    _firebaseInitialized = false;
    _appCheckInitialized = false;
    _initializationInProgress = false;
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