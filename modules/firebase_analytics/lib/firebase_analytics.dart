import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ensemble/framework/logging/log_provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics Provider with intelligent error handling
///
/// Automatically categorizes errors as fatal or non-fatal based on:
/// - Error type (OutOfMemoryError, critical system errors = fatal)
/// - Source library (engine/flutter core errors may be fatal)
/// - Error context (UI errors, widget errors = non-fatal)
class FirebaseAnalyticsProvider extends LogProvider {
  FirebaseOptions? firebaseOptions;
  FirebaseAnalytics? _analytics;
  final FirebaseApp? _providedFirebaseApp; // Store the provided Firebase app

  // Constructor accepts optional Firebase app (called from EnsembleModules)
  FirebaseAnalyticsProvider([this._providedFirebaseApp]);

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

  /// Custom error handler that distinguishes between fatal and non-fatal errors
  void _handleFlutterError(FlutterErrorDetails errorDetails) {
    // Check if this is a fatal error based on the error type or context
    bool isFatal = _shouldTreatAsFatal(errorDetails);

    if (isFatal) {
      // Record as fatal error
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    } else {
      // Record as non-fatal error
      FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
    }
  }

  /// Determine if an error should be treated as fatal
  bool _shouldTreatAsFatal(FlutterErrorDetails errorDetails) {
    final exception = errorDetails.exception;
    final library = errorDetails.library;

    // Whitelist of error types that should be treated as fatal
    const Set<Type> _fatalErrorTypes = {
      OutOfMemoryError,
      UnimplementedError,
      UnsupportedError,
      AssertionError,
    };

    // Treat as fatal if:
    // 1. It's an error type in the whitelist
    // 2. It's a system-level error
    // 3. It's from critical libraries
    if (_fatalErrorTypes.contains(exception.runtimeType)) {
      return true;
    }

    // Check for critical errors in core Flutter libraries
    if (library == 'flutter' || library == 'engine') {
      // Some specific error types that should be fatal
      if (exception.toString().contains('RenderObject') ||
          exception.toString().contains('Unable to load asset') ||
          exception.toString().contains('MissingPluginException')) {
        return true;
      }
    }

    // Default to non-fatal for UI-related errors, widget errors, etc.
    return false;
  }

  @override
  Future<void> init(
      {Map? options, String? ensembleAppId, bool shouldAwait = false}) async {
    _init(
        options: options,
        ensembleAppId: ensembleAppId,
        shouldAwait: shouldAwait);
    bool isFirebaseAppInitialized = false;
    // PRIORITY: If we have a provided Firebase app from constructor, use it to initialize Analytics
    if (_providedFirebaseApp != null) {
      try {
        _analytics = FirebaseAnalytics.instanceFor(app: _providedFirebaseApp);
        isFirebaseAppInitialized = true;
        // Setup crash reporting if available
        try {
          FlutterError.onError = _handleFlutterError;

          // Handle errors outside of Flutter framework (like async errors)
          PlatformDispatcher.instance.onError = (error, stack) {
            FirebaseCrashlytics.instance.recordError(error, stack,
                fatal: _shouldTreatAsyncErrorAsFatal(error));
            return true;
          };
        } catch (e) {
          print('Flutter: ⚠️ Firebase Crashlytics not available: $e');
        }
        return; // Success - exit early
      } catch (e) {
        print(
            'Flutter: ❌ Failed to initialize Firebase Analytics with provided app: $e');
      }
    }

    try {
      isFirebaseAppInitialized =
          Firebase.apps.any((app) => app.name == Firebase.app().name);
    } catch (e) {
      // Firebase flutter web implementation throws error of uninitialized project
      // When project is not initialized which means we just catch the error and ignore it
    }

    if (!isFirebaseAppInitialized) {
      try {
        await Firebase.initializeApp(
          // has to be the default app for the analytics to work on native apps
          options: firebaseOptions,
        );
      } catch (e) {
        print(
            "Failed to initialize firebase app, make sure you either have the firebase options specified in the config file (required for web) "
            "or have the right google file for the platform - google-services.json for android and GoogleService-Info.plist for iOS.");
        rethrow;
      }
    } else {
      FirebaseApp defaultApp = Firebase.app();
      if (firebaseOptions != null &&
          defaultApp.options.appId != firebaseOptions!.appId) {
        throw ConfigError(
            'The appId: ${firebaseOptions?.appId} specified in the Firebase configuration for ensembleapp with id: ${ensembleAppId ?? 'undefined'} is not the default firebase app. '
            'And the firebase default app has already been initialized. Firebase analytics can only work with the default firebase app');
      }
    }
    _analytics = FirebaseAnalytics.instance;

    // Setup comprehensive error handling
    FlutterError.onError = _handleFlutterError;

    // Handle async errors that aren't caught by Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack,
          fatal: _shouldTreatAsyncErrorAsFatal(error));
      return true;
    };
  }

  /// Determine if an async error should be treated as fatal
  bool _shouldTreatAsyncErrorAsFatal(Object error) {
    // Treat as fatal if:
    // 1. OutOfMemoryError
    // 2. Critical system errors
    // 3. Security-related errors
    if (error is OutOfMemoryError ||
        error.toString().contains('Permission denied') ||
        error.toString().contains('Network security') ||
        error.toString().contains('SecurityException')) {
      return true;
    }

    // Default to non-fatal for most async errors (network timeouts, etc.)
    return false;
  }

  Map<String, Object> convertMap(Map<String, dynamic> input) {
    return Map<String, Object>.fromEntries(input.entries
        .where((entry) => entry.value != null)
        .map((entry) => MapEntry(entry.key, entry.value as Object)));
  }

  Future<void> logEvent(
      String event, Map<String, dynamic> parameters, LogLevel level) async {
    _analytics?.logEvent(name: event, parameters: convertMap(parameters));
    print('Firebase: Logged event: $event with parameters: $parameters');
  }

  Future<void> setUserId(String userId) async {
    await _analytics?.setUserId(id: userId);
    print('Firebase: Set user ID: $userId');
  }

  Future<void> logAddToCart(
    List<AnalyticsEventItem>? items,
    double? value,
    String? currency,
    Map<String, Object?>? parameters,
  ) async {
    await _analytics?.logAddToCart(
      value: value,
      currency: currency,
      items: items,
      parameters: parameters,
    );
  }

  Future<void> logViewCart(
    String currency,
    List<AnalyticsEventItem> items,
    double value,
    Map<String, Object?> parameters,
  ) async {
    await _analytics?.logViewCart(
      currency: currency,
      value: value,
      items: items,
      parameters: parameters,
    );
  }

  Future<void> setUserProperty(String name, String value) async {
    await _analytics?.setUserProperty(
      name: name,
      value: value,
    );
  }

  Future<void> logAddPaymentInfo(
      String? coupon,
      String? currency,
      String? paymentType,
      double? value,
      List<AnalyticsEventItem>? items,
      Map<String, Object?>? parameters) async {
    await _analytics?.logAddPaymentInfo(
      parameters: parameters,
      coupon: coupon,
      currency: currency,
      paymentType: paymentType,
      value: value,
      items: items,
    );
  }

  Future<void> logAddShippingInfo(
      String? coupon,
      String? currency,
      String? shippingTier,
      double? value,
      List<AnalyticsEventItem>? items,
      Map<String, Object?>? parameters) async {
    await _analytics?.logAddShippingInfo(
      parameters: parameters,
      coupon: coupon,
      currency: currency,
      shippingTier: shippingTier,
      value: value,
      items: items,
    );
  }

  Future<void> logAddToWishlist(
    List<AnalyticsEventItem>? items,
    double? value,
    String? currency,
    Map<String, Object?>? parameters,
  ) async {
    await _analytics?.logAddToWishlist(
      items: items,
      parameters: parameters,
      value: value,
      currency: currency,
    );
  }

  Future<void> logBeginCheckout(
    double? value,
    String? currency,
    List<AnalyticsEventItem>? items,
    String? coupon,
    Map<String, Object?>? parameters,
  ) async {
    await _analytics?.logBeginCheckout(
      value: value,
      currency: currency,
      items: items,
      coupon: coupon,
      parameters: parameters,
    );
  }

  Future<void> logViewItem(
    String? currency,
    double? value,
    List<AnalyticsEventItem>? items,
    Map<String, Object?>? parameters,
  ) async {
    await _analytics?.logViewItem(
      currency: currency,
      value: value,
      items: items,
      parameters: parameters,
    );
  }

  Future<void> logViewItemList(
    List<AnalyticsEventItem>? items,
    String? itemListId,
    String? itemListName,
    Map<String, Object?>? parameters,
  ) async {
    await _analytics?.logViewItemList(
      items: items,
      itemListId: itemListId,
      itemListName: itemListName,
      parameters: parameters,
    );
  }

  Future<void> logRefund(
    String? currency,
    double? value,
    List<AnalyticsEventItem>? items,
    Map<String, Object?>? parameters,
  ) async {
    await _analytics?.logRefund(
      currency: currency,
      value: value,
      items: items,
      parameters: parameters,
    );
  }

  Future<void> log(Map<String, dynamic> config) async {
    var operation = config['operation'] ?? 'logEvent';
    var provider = config['provider'] ?? 'firebase';

    if (provider == 'firebase') {
      if (operation == 'logEvent' && config.containsKey('name')) {
        await logEvent(
          config['name'],
          Map<String, dynamic>.from(config['parameters']),
          config['logLevel'] ?? LogLevel.info,
        );
      } else if (operation == 'setUserId' && config.containsKey('userId')) {
        await setUserId(config['userId']);
      } else if (operation == 'logAddToCart') {
        await logAddToCart(
          config['items'] ?? [],
          config['value'] ?? 0.0,
          config['currency'] ?? 'USD',
          config['parameters'] ?? {},
        );
      } else if (operation == 'logViewCart') {
        await logViewCart(
          config['currency'] ?? 'USD',
          config['items'] ?? [],
          config['value'] ?? 0.0,
          config['parameters'] ?? {},
        );
      } else if (operation == 'setUserProperty') {
        await setUserProperty(
          config['name'],
          config['value'],
        );
      } else if (operation == 'logAddPaymentInfo') {
        await logAddPaymentInfo(
          config['coupon'],
          config['currency'],
          config['paymentType'],
          config['value'],
          config['items'],
          config['parameters'],
        );
      } else if (operation == 'logAddShippingInfo') {
        await logAddShippingInfo(
          config['coupon'],
          config['currency'],
          config['shippingTier'],
          config['value'],
          config['items'],
          config['parameters'],
        );
      } else if (operation == 'logAddToWishlist') {
        await logAddToWishlist(
          config['items'] ?? [],
          config['value'] ?? 0.0,
          config['currency'] ?? 'USD',
          config['parameters'] ?? {},
        );
      } else if (operation == 'logBeginCheckout') {
        await logBeginCheckout(
          config['value'] ?? 0.0,
          config['currency'] ?? 'USD',
          config['items'] ?? [],
          config['coupon'],
          config['parameters'] ?? {},
        );
      } else if (operation == 'logViewItem') {
        await logViewItem(
          config['currency'] ?? 'USD',
          config['value'] ?? 0.0,
          config['items'] ?? [],
          config['parameters'] ?? {},
        );
      } else if (operation == 'logViewItemList') {
        await logViewItemList(
          config['items'] ?? [],
          config['itemListId'],
          config['itemListName'],
          config['parameters'] ?? {},
        );
      } else if (operation == 'logRefund') {
        await logRefund(
          config['currency'] ?? 'USD',
          config['value'] ?? 0.0,
          config['items'] ?? [],
          config['parameters'] ?? {},
        );
      }
    }
  }
}
