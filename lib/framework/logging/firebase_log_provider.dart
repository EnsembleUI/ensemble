import 'package:ensemble/framework/error_handling.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ensemble/framework/logging/log_provider.dart';

class FirebaseAnalyticsProvider extends LogProvider {
  final FirebaseOptions? firebaseOptions;
  final String? _ensembleAppId;
  late FirebaseApp _firebaseApp;
  late FirebaseAnalytics _analytics;

  FirebaseAnalyticsProvider(this.firebaseOptions, this._ensembleAppId, {bool shouldAwait = false})
      : super(shouldAwait: shouldAwait);

  @override
  Future<void> init() async {
    bool isFirebaseAppInitialized = false;
    try {
      isFirebaseAppInitialized = Firebase.apps.any((app) => app.name == Firebase.app().name);
    } catch (e) {
      /// Firebase flutter web implementation throws error of uninitialized project
      /// When project is no initialized which means we just catch the error and ignore it
    }
    //we have to first check if the default app has been initialized or not and if the default app has the
    //same appId as the one passed in configuration. Throw an exception if this is not true.
    if ( !isFirebaseAppInitialized ) {
      try {
        _firebaseApp = await Firebase.initializeApp(
          //has to be the default app for the analytics to work on native apps
          options: firebaseOptions,
        );
      } catch (e) {
        print("failed to initialize firebase app, make sure you either have the firebase options specified in the config file (required for web) "
            "or have the right google file for the platform - google-services.json for android and GoogleService-Info.plist for iOS.");
        rethrow;
      }
    } else {
      FirebaseApp defaultApp = Firebase.app();
      if ( firebaseOptions != null && defaultApp.options.appId != firebaseOptions!.appId ) {
        throw ConfigError('The appId: ${firebaseOptions?.appId} specified in the Firebase configuration for ensembleapp with id: $_ensembleAppId is not the default firebase app. '
            'And the firebase default app has already been initialized. Firebase analytics can only work with the default firebase app');
      }
      _firebaseApp = defaultApp;
    }
    _analytics = FirebaseAnalytics.instance;
  }

  @override
  Future<void> log(String event, Map<String, dynamic> parameters, LogLevel level) async {
    // Use _firebaseApp for logging...
    _analytics.logEvent(name: event, parameters: parameters);
    print('Firebase: Logged event: $event with parameters: $parameters');
  }
}
