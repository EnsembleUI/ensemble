import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:yaml/yaml.dart';

import 'package:firebase_app_check/firebase_app_check.dart';

class FirebaseFunctionsAPIProvider extends APIProvider {
  // final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1', // Use your region
  );
  // Static variables to track App Check initialization
  static bool _appCheckInitialized = false;
  static bool _initializationInProgress = false;

  static Future<void> initializeFirebaseAppCheck() async {
    if (_appCheckInitialized || _initializationInProgress) {
      log('Firebase App Check already initialized or initialization in progress');
      return;
    }

    _initializationInProgress = true;

    try {
      log('Initializing Firebase App Check...');

      if (kDebugMode) {
        // Use debug provider for development
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
      } else {
        // Use production providers
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
      }

      _appCheckInitialized = true;
      log('Firebase App Check initialized successfully');
    } catch (e) {
      log('Failed to initialize Firebase App Check: $e');

      // In debug mode, we can continue without App Check
      if (kDebugMode) {
        log('Continuing without App Check in debug mode');
        _appCheckInitialized = false;
      } else {
        // In production, you might want to throw the error
        rethrow;
      }
    } finally {
      _initializationInProgress = false;
    }
  }

  /// Get the initialization status
  static bool get isAppCheckInitialized => _appCheckInitialized;

  /// Reset initialization status (useful for testing)
  static void resetInitialization() {
    _appCheckInitialized = false;
    _initializationInProgress = false;
  }

  @override
  Future<void> init(String appId, Map<String, dynamic> config) async {
    // Firebase Functions initialization can happen here if needed
    // Default region can be set here if provided in config
    if (config['region'] != null) {
      _functions.useFunctionsEmulator(config['emulatorHost'] ?? 'localhost',
          config['emulatorPort'] ?? 5001);
    }
  }

  @override
  Future<Response> invokeApi(BuildContext context, YamlMap api,
      DataContext eContext, String apiName) async {
    // Extract the function name from the API definition
    String name = eContext.eval(api['name'] ?? '')?.toString() ?? '';
    if (name.isEmpty) {
      throw RuntimeError('Function name cannot be empty');
    }

    // Get region if specified, otherwise use default
    String? region = eContext.eval(api['region'])?.toString();
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
      HttpsCallable callable;
      callable = _functions.httpsCallable(name);
      final result;
      result = await callable.call(data);

      // Process response
      return FirebaseFunctionResponse(
        result.data,
        {'Content-Type': 'application/json'},
        200, // Firebase Functions returns 200 when successful
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
  dispose() {
    // Nothing specific to dispose
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
