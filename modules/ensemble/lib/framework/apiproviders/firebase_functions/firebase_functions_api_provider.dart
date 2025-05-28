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
  static FirebaseApp? _app;

  // Static variables to track initialization
  static bool _firebaseInitialized = false;
  static bool _appCheckInitialized = false;
  static FirebaseOptions? firebaseOptions;

  static get platformOptions => null;

  // Check if Firebase Functions API provider is enabled
  static FirebaseApp? getFirebaseAppContext(){
    return _app;
  }
  bool _isFirebaseProviderEnabled() {
    try {
      EnsembleConfig? config = Ensemble().getConfig();
      if (config == null) {
        return false;
      }

      UserAppConfig? appConfig = config.definitionProvider.getAppConfig();
      if (appConfig == null) {
        return false;
      }

      List<String> apiProviders =
          appConfig.envVariables!['api_providers'].toString().split(',');
      if (!apiProviders.contains('firebase')) {
        throw ConfigError(
            'cloud_function_provider environment variable is not initialized');
      }
      else{
        return true;
      }

    } catch (e) {
      return false;
    }
  }

  /// Initialize Firebase if not already initialized
  static Future<void> _initializeFirebase() async {
    bool areOptionsEqual(FirebaseOptions a, FirebaseOptions b) {
      return a.apiKey == b.apiKey &&
          a.appId == b.appId &&
          a.messagingSenderId == b.messagingSenderId &&
          a.projectId == b.projectId;
    }


    try {
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
          name: 'firebaseFunctions',
          options: firebaseOptions,
        );
        _app = app;
      }
    } catch (e) {
      throw RuntimeError('Firebase initialization failed: $e');
    }
  }
  /// Initialize Firebase App Check with Firebase dependency check
  static Future<void> initializeFirebaseAppCheck() async {

    try {
      if (_app == null) {
        await _initializeFirebase();
      }
      if (_app?.options.apiKey != null) {
      FirebaseAppCheck appCheck = FirebaseAppCheck.instanceFor(app: _app!);
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
      }
      else{
         await _initializeFirebase();
      }
    } catch (e) {
      _appCheckInitialized = false;
      
      throw ConfigError('Failed to initialize Firebase App Check: $e');
    }
  }

  @override
  Future<void> init(String appId, Map<String, dynamic> config) async {
    FirebaseConfig firebaseConfig = FirebaseConfig.fromMap(config);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      firebaseOptions = firebaseConfig.iOSConfig;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      firebaseOptions = firebaseConfig.androidConfig;
    } else if (kIsWeb) {
      firebaseOptions = firebaseConfig.webConfig;
    }
    await _initializeFirebase();
  }

  @override
  Future<Response> invokeApi(BuildContext context, YamlMap api,
      DataContext eContext, String apiName) async {
    // Check if Firebase provider is enabled in environment variables
    if (!_isFirebaseProviderEnabled()) {
      throw ConfigError('Please include firebase in api_provider to use this function');
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


    // Create Functions instance for the specified region
    FirebaseFunctions functionsInstance;
    try {
      functionsInstance =
          FirebaseFunctions.instanceFor(app: _app, region: region);
    } catch (e) {
      throw ConfigError('Failed to create Firebase Functions instance: $e');
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
