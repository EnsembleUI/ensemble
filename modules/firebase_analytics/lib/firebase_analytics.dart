import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ensemble/framework/logging/log_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class FirebaseAnalyticsProvider extends LogProvider {
  FirebaseOptions? firebaseOptions;
  FirebaseAnalytics? _analytics;
  void _init({Map? options, String? ensembleAppId, bool shouldAwait = false}) {
    this.options = options;
    this.ensembleAppId = ensembleAppId;
    this.shouldAwait = shouldAwait;
    if (options != null) {
      FirebaseConfig config = FirebaseConfig.fromMap(options);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        firebaseOptions = config.iOSConfig;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        firebaseOptions = config.androidConfig;
      } else if (kIsWeb) {
        firebaseOptions = config.webConfig;
      }
    }
  }

  @override
  Future<void> init({Map? options,String? ensembleAppId,bool shouldAwait = false}) async {
    _init(options: options, ensembleAppId: ensembleAppId, shouldAwait: shouldAwait);
    bool isFirebaseAppInitialized = false;
    try {
      isFirebaseAppInitialized =
          Firebase.apps.any((app) => app.name == Firebase.app().name);
    } catch (e) {
      /// Firebase flutter web implementation throws error of uninitialized project
      /// When project is no initialized which means we just catch the error and ignore it
    }
    //we have to first check if the default app has been initialized or not and if the default app has the
    //same appId as the one passed in configuration. Throw an exception if this is not true.
    if (!isFirebaseAppInitialized) {
      try {
        await Firebase.initializeApp(
          //has to be the default app for the analytics to work on native apps
          options: firebaseOptions,
        );
      } catch (e) {
        print(
            "failed to initialize firebase app, make sure you either have the firebase options specified in the config file (required for web) "
                "or have the right google file for the platform - google-services.json for android and GoogleService-Info.plist for iOS.");
        rethrow;
      }
    } else {
      FirebaseApp defaultApp = Firebase.app();
      if (firebaseOptions != null &&
          defaultApp.options.appId != firebaseOptions!.appId) {
        throw ConfigError(
            'The appId: ${firebaseOptions?.appId} specified in the Firebase configuration for ensembleapp with id: ${ensembleAppId??'undefined'} is not the default firebase app. '
                'And the firebase default app has already been initialized. Firebase analytics can only work with the default firebase app');
      }
    }
    _analytics = FirebaseAnalytics.instance;
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  @override
  Future<void> log(
      String event, Map<String, dynamic> parameters, LogLevel level) async {
    // Use _firebaseApp for logging...
    _analytics?.logEvent(name: event, parameters: parameters);
    print('Firebase: Logged event: $event with parameters: $parameters');
  }
}
