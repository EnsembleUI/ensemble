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
    await _analytics?.logEvent(name: event, parameters: convertMap(parameters));
    print('Firebase: Logged event: $event with parameters: $parameters');
  }

  Future<void> setUserId(String userId) async {
    await _analytics?.setUserId(id: userId);
    print('Firebase: Set user ID: $userId');
  }

  @override
  Future<void> log(Map<String, dynamic> config) async {
    final operation = config['operation'] ?? 'logEvent';
    final provider = config['provider'] ?? 'firebase';

    if (provider != 'firebase') {
      print('FirebaseAnalyticsProvider: Unsupported provider: $provider');
      return; // Not a Firebase operation
    }

    try {
      switch (operation) {
        // Core event logging
        case 'logEvent':
          await _handleLogEvent(config);
          break;

        // Screen tracking
        case 'logScreenView':
          print('Firebase: Logging screen view: ${config['screenName']}');
          await _handleLogScreenView(config);
          break;

        // User lifecycle
        case 'logLogin':
          await _handleLogLogin(config);
          break;
        case 'logSignUp':
          await _handleLogSignUp(config);
          break;
        case 'logAppOpen':
          await _handleLogAppOpen(config);
          break;

        // Content and interaction
        case 'logSelectContent':
          await _handleLogSelectContent(config);
          break;
        case 'logShare':
          await _handleLogShare(config);
          break;
        case 'logSearch':
          await _handleLogSearch(config);
          break;
        case 'logViewSearchResults':
          await _handleLogViewSearchResults(config);
          break;

        // Gaming and achievements
        case 'logLevelUp':
          await _handleLogLevelUp(config);
          break;
        case 'logLevelStart':
          await _handleLogLevelStart(config);
          break;
        case 'logLevelEnd':
          await _handleLogLevelEnd(config);
          break;
        case 'logPostScore':
          await _handleLogPostScore(config);
          break;
        case 'logUnlockAchievement':
          await _handleLogUnlockAchievement(config);
          break;
        case 'logEarnVirtualCurrency':
          await _handleLogEarnVirtualCurrency(config);
          break;
        case 'logSpendVirtualCurrency':
          await _handleLogSpendVirtualCurrency(config);
          break;

        // Tutorial and onboarding
        case 'logTutorialBegin':
          await _handleLogTutorialBegin(config);
          break;
        case 'logTutorialComplete':
          await _handleLogTutorialComplete(config);
          break;

        // Social features
        case 'logJoinGroup':
          await _handleLogJoinGroup(config);
          break;

        // Marketing and attribution
        case 'logGenerateLead':
          await _handleLogGenerateLead(config);
          break;
        case 'logCampaignDetails':
          await _handleLogCampaignDetails(config);
          break;
        case 'logAdImpression':
          await _handleLogAdImpression(config);
          break;

        // E-COMMERCE FUNCTIONS
        case 'logAddPaymentInfo':
          await _handleLogAddPaymentInfo(config);
          break;
        case 'logAddShippingInfo':
          await _handleLogAddShippingInfo(config);
          break;
        case 'logAddToCart':
          await _handleLogAddToCart(config);
          break;
        case 'logAddToWishlist':
          await _handleLogAddToWishlist(config);
          break;
        case 'logBeginCheckout':
          await _handleLogBeginCheckout(config);
          break;
        case 'logPurchase':
          await _handleLogPurchase(config);
          break;
        case 'logRemoveFromCart':
          await _handleLogRemoveFromCart(config);
          break;
        case 'logViewCart':
          await _handleLogViewCart(config);
          break;
        case 'logViewItem':
          await _handleLogViewItem(config);
          break;
        case 'logViewItemList':
          await _handleLogViewItemList(config);
          break;
        case 'logSelectItem':
          await _handleLogSelectItem(config);
          break;
        case 'logSelectPromotion':
          await _handleLogSelectPromotion(config);
          break;
        case 'logViewPromotion':
          await _handleLogViewPromotion(config);
          break;
        case 'logRefund':
          await _handleLogRefund(config);
          break;

        // Configuration methods
        case 'setUserId':
          await _handleSetUserId(config);
          break;
        case 'setUserProperty':
          await _handleSetUserProperty(config);
          break;
        case 'setAnalyticsCollectionEnabled':
          await _handleSetAnalyticsCollectionEnabled(config);
          break;
        case 'setConsent':
          await _handleSetConsent(config);
          break;
        case 'setDefaultEventParameters':
          await _handleSetDefaultEventParameters(config);
          break;
        case 'setSessionTimeoutDuration':
          await _handleSetSessionTimeoutDuration(config);
          break;
        case 'resetAnalyticsData':
          await _handleResetAnalyticsData(config);
          break;

        // iOS-specific conversion methods
        case 'initiateOnDeviceConversionMeasurementWithEmailAddress':
          await _handleInitiateOnDeviceConversionMeasurementWithEmailAddress(
              config);
          break;
        case 'initiateOnDeviceConversionMeasurementWithPhoneNumber':
          await _handleInitiateOnDeviceConversionMeasurementWithPhoneNumber(
              config);
          break;
        case 'initiateOnDeviceConversionMeasurementWithHashedEmailAddress':
          await _handleInitiateOnDeviceConversionMeasurementWithHashedEmailAddress(
              config);
          break;
        case 'initiateOnDeviceConversionMeasurementWithHashedPhoneNumber':
          await _handleInitiateOnDeviceConversionMeasurementWithHashedPhoneNumber(
              config);
          break;

        default:
          throw ConfigError(
              'Unsupported Firebase Analytics operation: $operation');
      }
    } catch (e) {
      print('Firebase Analytics Error: $e');
      rethrow;
    }
  }

  // Individual method handlers
  Future<void> _handleLogEvent(Map<String, dynamic> config) async {
    await logEvent(
      config['name'],
      Map<String, dynamic>.from(config['parameters'] ?? {}),
      config['logLevel'] ?? LogLevel.info,
    );
  }

  Future<void> _handleLogScreenView(Map<String, dynamic> config) async {
    print('Firebase: Logging screen view: ${config['screenName']}');
    await _analytics?.logScreenView(
      screenName: config['screenName'],
      screenClass: config['screenClass'] ?? 'Flutter',
    );
    print('Firebase: Logged screen view: ${config['screenName']}');
  }

  Future<void> _handleLogLogin(Map<String, dynamic> config) async {
    await _analytics?.logLogin(loginMethod: config['loginMethod']);
    print('Firebase: Logged login with method: ${config['loginMethod']}');
  }

  Future<void> _handleLogSignUp(Map<String, dynamic> config) async {
    await _analytics?.logSignUp(signUpMethod: config['signUpMethod']);
    print('Firebase: Logged sign up with method: ${config['signUpMethod']}');
  }

  Future<void> _handleLogAppOpen(Map<String, dynamic> config) async {
    await _analytics?.logAppOpen(
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged app open');
  }

  Future<void> _handleLogSelectContent(Map<String, dynamic> config) async {
    await _analytics?.logSelectContent(
      contentType: config['contentType'],
      itemId: config['itemId'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print(
        'Firebase: Logged select content: ${config['contentType']}/${config['itemId']}');
  }

  Future<void> _handleLogShare(Map<String, dynamic> config) async {
    await _analytics?.logShare(
      contentType: config['contentType'],
      itemId: config['itemId'],
      method: config['method'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print(
        'Firebase: Logged share: ${config['contentType']}/${config['itemId']} via ${config['method']}');
  }

  Future<void> _handleLogSearch(Map<String, dynamic> config) async {
    await _analytics?.logSearch(
      searchTerm: config['searchTerm'],
      numberOfNights: config['numberOfNights'],
      numberOfRooms: config['numberOfRooms'],
      numberOfPassengers: config['numberOfPassengers'],
      origin: config['origin'],
      destination: config['destination'],
      startDate: config['startDate'],
      endDate: config['endDate'],
      travelClass: config['travelClass'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged search: ${config['searchTerm']}');
  }

  Future<void> _handleLogViewSearchResults(Map<String, dynamic> config) async {
    await _analytics?.logViewSearchResults(
      searchTerm: config['searchTerm'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged view search results: ${config['searchTerm']}');
  }

  Future<void> _handleLogLevelUp(Map<String, dynamic> config) async {
    await _analytics?.logLevelUp(
      level: config['level'],
      character: config['character'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged level up: ${config['level']}');
  }

  Future<void> _handleLogLevelStart(Map<String, dynamic> config) async {
    await _analytics?.logLevelStart(
      levelName: config['levelName'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged level start: ${config['levelName']}');
  }

  Future<void> _handleLogLevelEnd(Map<String, dynamic> config) async {
    await _analytics?.logLevelEnd(
      levelName: config['levelName'],
      success: config['success'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged level end: ${config['levelName']}');
  }

  Future<void> _handleLogPostScore(Map<String, dynamic> config) async {
    await _analytics?.logPostScore(
      score: config['score'],
      level: config['level'],
      character: config['character'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged post score: ${config['score']}');
  }

  Future<void> _handleLogUnlockAchievement(Map<String, dynamic> config) async {
    await _analytics?.logUnlockAchievement(
      id: config['achievementId'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged unlock achievement: ${config['achievementId']}');
  }

  Future<void> _handleLogEarnVirtualCurrency(
      Map<String, dynamic> config) async {
    await _analytics?.logEarnVirtualCurrency(
      virtualCurrencyName: config['virtualCurrencyName'],
      value: config['value'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print(
        'Firebase: Logged earn virtual currency: ${config['virtualCurrencyName']} = ${config['value']}');
  }

  Future<void> _handleLogSpendVirtualCurrency(
      Map<String, dynamic> config) async {
    await _analytics?.logSpendVirtualCurrency(
      itemName: config['itemName'],
      virtualCurrencyName: config['virtualCurrencyName'],
      value: config['value'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print(
        'Firebase: Logged spend virtual currency: ${config['virtualCurrencyName']} = ${config['value']}');
  }

  Future<void> _handleLogTutorialBegin(Map<String, dynamic> config) async {
    await _analytics?.logTutorialBegin(
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged tutorial begin');
  }

  Future<void> _handleLogTutorialComplete(Map<String, dynamic> config) async {
    await _analytics?.logTutorialComplete(
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged tutorial complete');
  }

  Future<void> _handleLogJoinGroup(Map<String, dynamic> config) async {
    await _analytics?.logJoinGroup(
      groupId: config['groupId'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged join group: ${config['groupId']}');
  }

  Future<void> _handleLogGenerateLead(Map<String, dynamic> config) async {
    await _analytics?.logGenerateLead(
      currency: config['currency'],
      value: config['value']?.toDouble(),
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged generate lead');
  }

  Future<void> _handleLogCampaignDetails(Map<String, dynamic> config) async {
    await _analytics?.logCampaignDetails(
      source: config['source'],
      medium: config['medium'],
      campaign: config['campaign'],
      term: config['term'],
      content: config['content'],
      aclid: config['aclid'],
      cp1: config['cp1'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged campaign details: ${config['campaign']}');
  }

  Future<void> _handleLogAdImpression(Map<String, dynamic> config) async {
    await _analytics?.logAdImpression(
      adPlatform: config['adPlatform'],
      adSource: config['adSource'],
      adFormat: config['adFormat'],
      adUnitName: config['adUnitName'],
      value: config['value']?.toDouble(),
      currency: config['currency'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged ad impression');
  }

  // E-COMMERCE HANDLERS
  Future<void> _handleLogAddPaymentInfo(Map<String, dynamic> config) async {
    await _analytics?.logAddPaymentInfo(
      coupon: config['coupon'],
      currency: config['currency'],
      paymentType: config['paymentType'],
      value: config['value']?.toDouble(),
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged add payment info');
  }

  Future<void> _handleLogAddShippingInfo(Map<String, dynamic> config) async {
    await _analytics?.logAddShippingInfo(
      coupon: config['coupon'],
      currency: config['currency'],
      value: config['value']?.toDouble(),
      shippingTier: config['shippingTier'],
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged add shipping info');
  }

  Future<void> _handleLogAddToCart(Map<String, dynamic> config) async {
    await _analytics?.logAddToCart(
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      value: config['value']?.toDouble(),
      currency: config['currency'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged add to cart');
  }

  Future<void> _handleLogAddToWishlist(Map<String, dynamic> config) async {
    await _analytics?.logAddToWishlist(
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      value: config['value']?.toDouble(),
      currency: config['currency'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged add to wishlist');
  }

  Future<void> _handleLogBeginCheckout(Map<String, dynamic> config) async {
    await _analytics?.logBeginCheckout(
      value: config['value']?.toDouble(),
      currency: config['currency'],
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      coupon: config['coupon'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged begin checkout');
  }

  Future<void> _handleLogPurchase(Map<String, dynamic> config) async {
    await _analytics?.logPurchase(
      currency: config['currency'],
      coupon: config['coupon'],
      value: config['value']?.toDouble(),
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      tax: config['tax']?.toDouble(),
      shipping: config['shipping']?.toDouble(),
      transactionId: config['transactionId'],
      affiliation: config['affiliation'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged purchase');
  }

  Future<void> _handleLogRemoveFromCart(Map<String, dynamic> config) async {
    await _analytics?.logRemoveFromCart(
      currency: config['currency'],
      value: config['value']?.toDouble(),
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged remove from cart');
  }

  Future<void> _handleLogViewCart(Map<String, dynamic> config) async {
    await _analytics?.logViewCart(
      currency: config['currency'],
      value: config['value']?.toDouble(),
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged view cart');
  }

  Future<void> _handleLogViewItem(Map<String, dynamic> config) async {
    await _analytics?.logViewItem(
      currency: config['currency'],
      value: config['value']?.toDouble(),
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged view item');
  }

  Future<void> _handleLogViewItemList(Map<String, dynamic> config) async {
    await _analytics?.logViewItemList(
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      itemListId: config['itemListId'],
      itemListName: config['itemListName'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged view item list');
  }

  Future<void> _handleLogSelectItem(Map<String, dynamic> config) async {
    await _analytics?.logSelectItem(
      itemListId: config['itemListId'],
      itemListName: config['itemListName'],
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged select item');
  }

  Future<void> _handleLogSelectPromotion(Map<String, dynamic> config) async {
    await _analytics?.logSelectPromotion(
      creativeName: config['creativeName'],
      creativeSlot: config['creativeSlot'],
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      locationId: config['locationId'],
      promotionId: config['promotionId'],
      promotionName: config['promotionName'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged select promotion');
  }

  Future<void> _handleLogViewPromotion(Map<String, dynamic> config) async {
    await _analytics?.logViewPromotion(
      creativeName: config['creativeName'],
      creativeSlot: config['creativeSlot'],
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      locationId: config['locationId'],
      promotionId: config['promotionId'],
      promotionName: config['promotionName'],
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged view promotion');
  }

  Future<void> _handleLogRefund(Map<String, dynamic> config) async {
    await _analytics?.logRefund(
      currency: config['currency'],
      coupon: config['coupon'],
      value: config['value']?.toDouble(),
      tax: config['tax']?.toDouble(),
      shipping: config['shipping']?.toDouble(),
      transactionId: config['transactionId'],
      affiliation: config['affiliation'],
      items: config['items'] != null
          ? _convertToAnalyticsEventItems(config['items'])
          : null,
      parameters: config['parameters'] != null
          ? convertMap(config['parameters'])
          : null,
    );
    print('Firebase: Logged refund');
  }

  // Helper method to convert items to AnalyticsEventItem list
  List<AnalyticsEventItem>? _convertToAnalyticsEventItems(dynamic items) {
    if (items == null) return null;
    if (items is! List) return null;

    return items
        .map((item) {
          if (item is! Map) return null;
          return AnalyticsEventItem(
            itemName: item['itemName'],
            itemId: item['itemId'],
            itemCategory: item['itemCategory'],
            itemCategory2: item['itemCategory2'],
            itemCategory3: item['itemCategory3'],
            itemCategory4: item['itemCategory4'],
            itemCategory5: item['itemCategory5'],
            itemListId: item['itemListId'],
            itemListName: item['itemListName'],
            itemBrand: item['itemBrand'],
            itemVariant: item['itemVariant'],
            affiliation: item['affiliation'],
            coupon: item['coupon'],
            creativeName: item['creativeName'],
            creativeSlot: item['creativeSlot'],
            locationId: item['locationId'],
            price: item['price']?.toDouble(),
            quantity: item['quantity']?.toInt(),
            index: item['index']?.toInt(),
            promotionId: item['promotionId'],
            promotionName: item['promotionName'],
            currency: item['currency'],
            discount: item['discount']?.toDouble(),
          );
        })
        .where((item) => item != null)
        .cast<AnalyticsEventItem>()
        .toList();
  }

  Future<void> _handleSetUserId(Map<String, dynamic> config) async {
    await setUserId(config['userId']);
  }

  Future<void> _handleSetUserProperty(Map<String, dynamic> config) async {
    await _analytics?.setUserProperty(
      name: config['propertyName'],
      value: config['propertyValue'],
    );
    print(
        'Firebase: Set user property: ${config['propertyName']} = ${config['propertyValue']}');
  }

  Future<void> _handleSetAnalyticsCollectionEnabled(
      Map<String, dynamic> config) async {
    await _analytics?.setAnalyticsCollectionEnabled(config['enabled']);
    print('Firebase: Set analytics collection enabled: ${config['enabled']}');
  }

  Future<void> _handleSetConsent(Map<String, dynamic> config) async {
    await _analytics?.setConsent(
      adStorageConsentGranted: config['adStorageConsentGranted'],
      analyticsStorageConsentGranted: config['analyticsStorageConsentGranted'],
      adPersonalizationSignalsConsentGranted:
          config['adPersonalizationSignalsConsentGranted'],
      adUserDataConsentGranted: config['adUserDataConsentGranted'],
      functionalityStorageConsentGranted:
          config['functionalityStorageConsentGranted'],
      personalizationStorageConsentGranted:
          config['personalizationStorageConsentGranted'],
      securityStorageConsentGranted: config['securityStorageConsentGranted'],
    );
    print('Firebase: Set consent');
  }

  Future<void> _handleSetDefaultEventParameters(
      Map<String, dynamic> config) async {
    final parameters = config['defaultParameters'];
    if (parameters is Map<String, dynamic>) {
      await _analytics?.setDefaultEventParameters(convertMap(parameters));
      print('Firebase: Set default event parameters');
    }
  }

  Future<void> _handleSetSessionTimeoutDuration(
      Map<String, dynamic> config) async {
    final milliseconds = config['timeoutMilliseconds'] ?? config['timeout'];
    if (milliseconds != null) {
      await _analytics
          ?.setSessionTimeoutDuration(Duration(milliseconds: milliseconds));
      print('Firebase: Set session timeout duration: ${milliseconds}ms');
    }
  }

  Future<void> _handleResetAnalyticsData(Map<String, dynamic> config) async {
    await _analytics?.resetAnalyticsData();
    print('Firebase: Reset analytics data');
  }

  // iOS-SPECIFIC CONVERSION METHODS
  Future<void> _handleInitiateOnDeviceConversionMeasurementWithEmailAddress(
      Map<String, dynamic> config) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw ConfigError(
          'initiateOnDeviceConversionMeasurementWithEmailAddress() is only supported on iOS');
    }
    final emailAddress = config['emailAddress'];
    if (emailAddress == null) {
      throw ConfigError(
          'emailAddress is required for initiateOnDeviceConversionMeasurementWithEmailAddress');
    }
    await _analytics
        ?.initiateOnDeviceConversionMeasurementWithEmailAddress(emailAddress);
    print('Firebase: Initiated on-device conversion measurement with email');
  }

  Future<void> _handleInitiateOnDeviceConversionMeasurementWithPhoneNumber(
      Map<String, dynamic> config) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw ConfigError(
          'initiateOnDeviceConversionMeasurementWithPhoneNumber() is only supported on iOS');
    }
    final phoneNumber = config['phoneNumber'];
    if (phoneNumber == null) {
      throw ConfigError(
          'phoneNumber is required for initiateOnDeviceConversionMeasurementWithPhoneNumber');
    }
    await _analytics
        ?.initiateOnDeviceConversionMeasurementWithPhoneNumber(phoneNumber);
    print('Firebase: Initiated on-device conversion measurement with phone');
  }

  Future<void>
      _handleInitiateOnDeviceConversionMeasurementWithHashedEmailAddress(
          Map<String, dynamic> config) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw ConfigError(
          'initiateOnDeviceConversionMeasurementWithHashedEmailAddress() is only supported on iOS');
    }
    final hashedEmailAddress = config['hashedEmailAddress'];
    if (hashedEmailAddress == null) {
      throw ConfigError(
          'hashedEmailAddress is required for initiateOnDeviceConversionMeasurementWithHashedEmailAddress');
    }
    await _analytics
        ?.initiateOnDeviceConversionMeasurementWithHashedEmailAddress(
            hashedEmailAddress);
    print(
        'Firebase: Initiated on-device conversion measurement with hashed email');
  }

  Future<void>
      _handleInitiateOnDeviceConversionMeasurementWithHashedPhoneNumber(
          Map<String, dynamic> config) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw ConfigError(
          'initiateOnDeviceConversionMeasurementWithHashedPhoneNumber() is only supported on iOS');
    }
    final hashedPhoneNumber = config['hashedPhoneNumber'];
    if (hashedPhoneNumber == null) {
      throw ConfigError(
          'hashedPhoneNumber is required for initiateOnDeviceConversionMeasurementWithHashedPhoneNumber');
    }
    await _analytics
        ?.initiateOnDeviceConversionMeasurementWithHashedPhoneNumber(
            hashedPhoneNumber);
    print(
        'Firebase: Initiated on-device conversion measurement with hashed phone');
  }
}
