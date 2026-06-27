import 'package:ensemble/framework/action.dart' as ensembleAction;
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/logging/log_manager.dart';
import 'package:ensemble/framework/logging/log_provider.dart' as logging;
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/adobe_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/moengage_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:ensemble/framework/stub/moengage_manager.dart';

/// Ensemble action that sends analytics, attribution, or engagement events to the configured provider.
class LogEvent extends ensembleAction.EnsembleAction {
  /// Analytics event name sent to the selected provider.
  final String? eventName;
  /// Provider-specific analytics parameters evaluated from the YAML payload.
  final Map<dynamic, dynamic>? parameters;
  /// Provider selected by the YAML payload.
  final String? provider;
  /// Requested Wi-Fi or provider operation.
  final String? operation;
  /// User identifier associated with the analytics or engagement event.
  final String? userId;
  /// Severity level used when forwarding the event to logging providers.
  final String logLevel;
  /// Value written, logged, or passed to the target integration.
  final dynamic value;
  /// User attribute key updated by the analytics provider.
  final String? attributeKey;
  /// Original YAML payload retained for provider-specific validation.
  final Map? originalPayload;
  final ensembleAction.EnsembleAction? onSuccess;
  final ensembleAction.EnsembleAction? onError;

  /// Creates a [LogEvent] object.
  LogEvent({
    required Invokable? initiator,
    this.eventName,
    required this.logLevel,
    required this.provider,
    this.operation,
    this.userId,
    this.parameters,
    this.value,
    this.attributeKey,
    this.originalPayload,
    this.onSuccess,
    this.onError,
  }) : super(initiator: initiator);

  /// Creates a [LogEvent] from a YAML or map action payload.
  factory LogEvent.from({Invokable? initiator, Map? payload}) {
    payload = Utils.convertYamlToDart(payload);
    String? eventName = payload?['name'];
    String? operation = payload?['operation'];
    String? provider = payload?['provider'] ?? 'firebase';
    dynamic value = payload?['value'];
    String? attributeKey = payload?['attributeKey'];

    // Firebase validation
    if (provider == 'firebase') {
      Map<String, dynamic> validationPayload = {};
      if (payload != null) {
        payload.forEach((key, value) {
          if (key != null) {
            validationPayload[key.toString()] = value;
          }
        });
      }
      
      // Required Parameters validator for ALL Firebase operations 
      try {
        FirebaseAnalyticsValidator.validate(operation ?? 'logEvent', validationPayload);
      } catch (e) {
        throw LanguageError(
            "${ensembleAction.ActionType.logEvent.name} validation failed: ${e.toString()}");
      }
    }
    // MoEngage validations
    else if (provider == 'moengage') {
      if (operation == null) {
        throw LanguageError('MoEngage requires operation type');
      }

      // Value validation for operations requiring it
      if (value == null &&
          !NoValueOperations.values.any((e) => e.name == operation)) {
        throw LanguageError('Operation $operation requires a value');
      }

      // Operation-specific validations
      switch (operation) {
        case 'trackEvent':
          if (eventName == null) {
            throw LanguageError('trackEvent requires event name');
          }
          break;

        case 'setLocation':
        case 'setUserAttributeLocation':
          final location = EnsembleGeoLocation.parse(value);
          if (location == null) {
            throw LanguageError('Invalid location format');
          }
          break;

        case 'custom':
        case 'timestamp':
          if (attributeKey == null) {
            throw LanguageError('Operation $operation requires attributeKey');
          }
          break;

        case 'locationAttribute':
          if (attributeKey == null) {
            throw LanguageError('Operation $operation requires attributeKey');
          }
          final location = EnsembleGeoLocation.parse(value);
          if (location == null) {
            throw LanguageError('Invalid location format');
          }
          break;

        case 'setContext':
          if (value != null && value is! List) {
            throw LanguageError('setContext requires List value');
          }
          break;
      }
    } else if (provider == 'adobe') {
      if (operation == 'trackAction') {
        if (eventName == null) {
          throw LanguageError('trackAction requires event name');
        }
      } else if (operation == 'trackState') {
        if (eventName == null) {
          throw LanguageError('trackState requires event name');
        }
      } else if (operation == 'sendEvent') {
        if (eventName == null) {
          throw LanguageError('sendEvent requires event name');
        }
      }
    }

    return LogEvent(
      initiator: initiator,
      eventName: eventName,
      parameters: payload?['parameters'] is Map ? payload!['parameters'] : null,
      logLevel: payload?['logLevel'] ?? logging.LogLevel.info.name,
      provider: provider,
      operation: operation,
      userId: payload?['userId'],
      value: value,
      attributeKey: attributeKey,
      originalPayload: payload,
      onSuccess: ensembleAction.EnsembleAction.from(payload?['onSuccess']),
      onError: ensembleAction.EnsembleAction.from(payload?['onError']),
    );
  }

  static logging.LogLevel stringToLogLevel(String? levelStr) {
    if (levelStr == null) return logging.LogLevel.info;
    for (logging.LogLevel level in logging.LogLevel.values) {
      if (level.name.toLowerCase() == levelStr.toLowerCase()) {
        return level;
      }
    }
    return logging.LogLevel.info;
  }

  /// Runs this action and sends the configured event to its analytics provider.
  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      final evaluatedProvider = scopeManager.dataContext.eval(provider);

      if (evaluatedProvider == 'moengage') {
        await _handleMoEngageOperations(
          context,
          scopeManager,
          operation: scopeManager.dataContext.eval(operation),
          value: scopeManager.dataContext.eval(value),
          eventName: scopeManager.dataContext.eval(eventName),
          parameters: scopeManager.dataContext.eval(parameters),
          attributeKey: scopeManager.dataContext.eval(attributeKey),
        );

        if (onSuccess != null) {
          await ScreenController().executeAction(context, onSuccess!);
        }
      } else if (evaluatedProvider == 'adobe') {
        final result = await _handleAdobeOperations(
          context,
          scopeManager,
          operation: scopeManager.dataContext.eval(operation),
          eventName: scopeManager.dataContext.eval(eventName),
          parameters: scopeManager.dataContext.eval(parameters),
          attributeKey: scopeManager.dataContext.eval(attributeKey),
        );

        if (onSuccess != null) {
          await ScreenController().executeAction(
            context,
            onSuccess!,
            event: EnsembleEvent(null, data: result.toString()),
          );
        }
      } else {
        Map<String, dynamic> logData = {
          'name': scopeManager.dataContext.eval(eventName),
          'parameters': _convertToStringMap(scopeManager.dataContext.eval(parameters) ?? {}),
          'logLevel': stringToLogLevel(scopeManager.dataContext.eval(logLevel)),
          'provider': evaluatedProvider,
          'operation': scopeManager.dataContext.eval(operation) ?? 'logEvent',
          'userId': scopeManager.dataContext.eval(userId),
        };
        if (evaluatedProvider == 'firebase' && originalPayload != null) {
          // Extract Firebase parameters from originalPayload and add to logData
          for (FirebaseParams param in FirebaseParams.values) {
            final key = param.name;
            if (originalPayload!.containsKey(key)) {
              final value = scopeManager.dataContext.eval(originalPayload![key]);
              if (value != null) {
                logData[key] = value;
              }
            }
          }
        }
        LogManager().log(logging.LogType.appAnalytics, logData);
        if (onSuccess != null) {
          await ScreenController().executeAction(context, onSuccess!);
        }
      }
    } catch (error) {
      if (onError != null) {
        await ScreenController().executeAction(
          context,
          onError!,
          event: EnsembleEvent(null, error: error.toString()),
        );
      } else {
        rethrow;
      }
    }
  }

  /// Helper to convert Map<dynamic, dynamic> to Map<String, dynamic>
  Map<String, dynamic> _convertToStringMap(Map? input) {
    if (input == null) return {};
    
    Map<String, dynamic> result = {};
    input.forEach((key, value) {
      if (key != null) {
        result[key.toString()] = value;
      }
    });
    return result;
  }

  Future<void> _handleMoEngageOperations(
    BuildContext context,
    ScopeManager scopeManager, {
    String? operation,
    dynamic value,
    String? eventName,
    Map? parameters,
    String? attributeKey,
  }) async {
    final moEngage = GetIt.instance<MoEngageModule>();

    // Handle standard user operations
    switch (operation) {
      // User Attributes
      case 'setUniqueId':
        await moEngage.setUniqueId(Utils.getString(value, fallback: ''));
        break;
      case 'setUserName':
        await moEngage.setUserName(Utils.getString(value, fallback: ''));
        break;
      case 'setFirstName':
        await moEngage.setFirstName(Utils.getString(value, fallback: ''));
        break;
      case 'setLastName':
        await moEngage.setLastName(Utils.getString(value, fallback: ''));
        break;
      case 'setEmail':
        await moEngage.setEmail(Utils.getString(value, fallback: ''));
        break;
      case 'setPhoneNumber':
        await moEngage.setPhoneNumber(Utils.getString(value, fallback: ''));
        break;
      case 'setBirthDate':
        await moEngage.setBirthDate(Utils.getString(value, fallback: ''));
        break;
      case 'setGender':
        final ensembleGender = EnsembleGender.fromString(value?.toString());
        if (ensembleGender != null) {
          await moEngage.setGender(ensembleGender);
        }
        break;
      case 'setAlias':
        await moEngage.setAlias(Utils.getString(value, fallback: ''));
        break;
      case 'setLocation':
        final location = EnsembleGeoLocation.parse(value);
        if (location != null) {
          await moEngage.setLocation(location);
        }
        break;

      // Custom Attributes
      case 'custom':
        await moEngage.setUserAttribute(attributeKey!, value);
        break;
      case 'timestamp':
        await moEngage.setUserAttributeIsoDate(
            attributeKey!, Utils.getString(value, fallback: ''));
        break;
      case 'locationAttribute':
        final location = EnsembleGeoLocation.parse(value);
        if (location != null) {
          await moEngage.setUserAttributeLocation(attributeKey!, location);
        }
        break;

      // Tracking Events
      case 'trackEvent':
        if (parameters != null) {
          final ensembleProps = EnsembleProperties();
          parameters.forEach((key, value) {
            ensembleProps.addAttribute(key, value);
          });
          await moEngage.trackEvent(eventName!, ensembleProps);
        } else {
          await moEngage.trackEvent(eventName!);
        }
        break;

      // App Configuration
      case 'enableSdk':
        await moEngage.enableSdk();
        break;
      case 'disableSdk':
        await moEngage.disableSdk();
        break;
      case 'enableDataTracking':
        await moEngage.enableDataTracking();
        break;
      case 'disableDataTracking':
        await moEngage.disableDataTracking();
        break;
      case 'enableDeviceIdTracking':
        await moEngage.enableDeviceIdTracking();
        break;
      case 'disableDeviceIdTracking':
        await moEngage.disableDeviceIdTracking();
        break;
      case 'enableAndroidIdTracking':
        await moEngage.enableAndroidIdTracking();
        break;
      case 'disableAndroidIdTracking':
        await moEngage.disableAndroidIdTracking();
        break;
      case 'enableAdIdTracking':
        await moEngage.enableAdIdTracking();
        break;
      case 'disableAdIdTracking':
        await moEngage.disableAdIdTracking();
        break;
      case 'setAppStatus':
        final status = EnsembleAppStatus.fromString(value?.toString());
        if (status != null) {
          await moEngage.setAppStatus(status);
        }
        break;
      case 'logout':
        await moEngage.logout();
        break;
      case 'deleteUser':
        final success = await moEngage.deleteUser();
        if (!success) {
          throw Exception('Failed to delete user');
        }
        break;

      // Push Configuration
      case 'registerForPush':
        await moEngage.registerForPushNotification();
        break;
      case 'registerForProvisionalPush':
        await moEngage.registerForProvisionalPush();
        break;
      case 'passFCMToken':
        await moEngage.passFCMPushToken(value.toString());
        break;
      case 'passPushKitToken':
        await moEngage.passPushKitPushToken(value.toString());
        break;
      case 'passFCMPushPayload':
        await moEngage.passFCMPushPayload(Map<String, String>.from(value));
        break;
      case 'requestPushPermission':
        await moEngage.requestPushPermissionAndroid();
        break;
      case 'updatePermissionCount':
        await moEngage.updatePushPermissionRequestCountAndroid(value);
        break;
      case 'pushPermissionResponse':
        await moEngage.pushPermissionResponseAndroid(value);
        break;

      // Display Configuration
      case 'showInApp':
        await moEngage.showInApp();
        break;
      case 'showNudge':
        final position = EnsembleNudgePosition.fromString(value?.toString()) ??
            EnsembleNudgePosition.bottom;
        await moEngage.showNudge(position: position);
        break;
      case 'setContext':
        if (value is List) {
          final contextList = value.map((e) => e.toString()).toList();
          await moEngage.setCurrentContext(contextList);
        }
        break;
      case 'resetContext':
        await moEngage.resetCurrentContext();
        break;
    }
  }
}

Future<dynamic> _handleAdobeOperations(
  BuildContext context,
  ScopeManager scopeManager, {
  String? operation,
  String? eventName,
  Map<String, dynamic>? parameters,
  String? attributeKey,
}) async {
  final adobe = GetIt.instance<AdobeAnalyticsModule>();

  switch (operation) {
    case 'trackAction':
      return await adobe.trackAction(
          eventName!,
          parameters!
              .map((key, value) => MapEntry(key.toString(), value.toString())));
    case 'trackState':
      return await adobe.trackState(
          eventName!,
          parameters!
              .map((key, value) => MapEntry(key.toString(), value.toString())));
    case 'sendEvent':
      return await adobe.sendEvent(eventName!, parameters!);
    case 'setupAssurance':
      return await adobe.setupAssurance(parameters!);
    case 'getExperienceCloudId':
      return await adobe.getExperienceCloudId();
    case 'getIdentities':
      return await adobe.getIdentities();
    case 'getUrlVariables':
      return await adobe.getUrlVariables();
    case 'removeIdentity':
      return await adobe.removeIdentity(parameters!);
    case 'resetIdentities':
      return await adobe.resetIdentities();
    case 'setAdvertisingIdentifier':
      return await adobe.setAdvertisingIdentifier(
          parameters!['advertisingIdentifier'].toString());
    case 'updateIdentities':
      return await adobe.updateIdentities(parameters!);
    case 'getConsents':
      return await adobe.getConsents();
    case 'updateConsent':
      return await adobe.updateConsent(parameters!['allowed']);
    case 'setDefaultConsent':
      return await adobe.setDefaultConsent(parameters!['allowed']);
    case 'getUserAttributes':
      return await adobe.getUserAttributes(parameters!);
    case 'removeUserAttributes':
      return await adobe.removeUserAttributes(parameters!);
    case 'updateUserAttributes':
      return await adobe.updateUserAttributes(parameters!);
    default:
      throw LanguageError('Invalid operation: $operation');
  }
}

/// Firebase Analytics Validator handles ALL Firebase operations in one place
/// Validates Firebase Analytics event names and parameters before events are logged.
class FirebaseAnalyticsValidator {
  /// Validation rules keyed by Firebase Analytics operation name.
  static const Map<String, Map<String, dynamic>> validationRules = {
    'logEvent': {
      'required': ['name'],
    },
    'setUserId': {
      'required': ['userId'],
    },
    
    // Screen tracking  
    'logScreenView': {
      'required': ['screenName'],
      'optional': ['screenClass', 'parameters'],
    },
    
    // User lifecycle
    'logLogin': {
      'optional': ['loginMethod', 'parameters'],
    },
    'logSignUp': {
      'required': ['signUpMethod'],
      'optional': ['parameters'],
    },
    'logAppOpen': {
      'optional': ['parameters'],
    },
    
    // Content and interaction
    'logSelectContent': {
      'required': ['contentType', 'itemId'],
      'optional': ['parameters'],
    },
    'logShare': {
      'required': ['contentType', 'itemId', 'method'],
      'optional': ['parameters'],
    },
    'logSearch': {
      'required': ['searchTerm'],
      'optional': ['numberOfNights', 'numberOfRooms', 'numberOfPassengers', 'origin', 'destination', 'startDate', 'endDate', 'travelClass', 'parameters'],
    },
    'logViewSearchResults': {
      'required': ['searchTerm'],
      'optional': ['parameters'],
    },
    
    // Gaming and achievements
    'logLevelUp': {
      'required': ['level'],
      'optional': ['character', 'parameters'],
    },
    'logLevelStart': {
      'required': ['levelName'],
      'optional': ['parameters'],
    },
    'logLevelEnd': {
      'required': ['levelName'],
      'optional': ['success', 'parameters'],
    },
    'logPostScore': {
      'required': ['score'],
      'optional': ['level', 'character', 'parameters'],
    },
    'logUnlockAchievement': {
      'required': ['achievementId'],
      'optional': ['parameters'],
    },
    'logEarnVirtualCurrency': {
      'required': ['virtualCurrencyName', 'value'],
      'optional': ['parameters'],
    },
    'logSpendVirtualCurrency': {
      'required': ['itemName', 'virtualCurrencyName', 'value'],
      'optional': ['parameters'],
    },
    
    // Tutorial and onboarding
    'logTutorialBegin': {
      'optional': ['parameters'],
    },
    'logTutorialComplete': {
      'optional': ['parameters'],
    },
    
    // Social features
    'logJoinGroup': {
      'required': ['groupId'],
      'optional': ['parameters'],
    },
    
    // Marketing and attribution
    'logGenerateLead': {
      'optional': ['currency', 'value', 'parameters'],
    },
    'logCampaignDetails': {
      'required': ['source', 'medium', 'campaign'],
      'optional': ['term', 'content', 'aclid', 'cp1', 'parameters'],
    },
    'logAdImpression': {
      'optional': ['adPlatform', 'adSource', 'adFormat', 'adUnitName', 'value', 'currency', 'parameters'],
    },
    
    // E-COMMERCE OPERATIONS
    'logAddPaymentInfo': {
      'optional': ['coupon', 'currency', 'paymentType', 'value', 'items', 'parameters'],
    },
    'logAddShippingInfo': {
      'optional': ['coupon', 'currency', 'value', 'shippingTier', 'items', 'parameters'],
    },
    'logAddToCart': {
      'optional': ['items', 'value', 'currency', 'parameters'],
    },
    'logAddToWishlist': {
      'optional': ['items', 'value', 'currency', 'parameters'],
    },
    'logBeginCheckout': {
      'optional': ['value', 'currency', 'items', 'coupon', 'parameters'],
    },
    'logPurchase': {
      'optional': ['currency', 'coupon', 'value', 'items', 'tax', 'shipping', 'transactionId', 'affiliation', 'parameters'],
    },
    'logRemoveFromCart': {
      'optional': ['currency', 'value', 'items', 'parameters'],
    },
    'logViewCart': {
      'optional': ['currency', 'value', 'items', 'parameters'],
    },
    'logViewItem': {
      'optional': ['currency', 'value', 'items', 'parameters'],
    },
    'logViewItemList': {
      'optional': ['items', 'itemListId', 'itemListName', 'parameters'],
    },
    'logSelectItem': {
      'optional': ['itemListId', 'itemListName', 'items', 'parameters'],
    },
    'logSelectPromotion': {
      'optional': ['creativeName', 'creativeSlot', 'items', 'locationId', 'promotionId', 'promotionName', 'parameters'],
    },
    'logViewPromotion': {
      'optional': ['creativeName', 'creativeSlot', 'items', 'locationId', 'promotionId', 'promotionName', 'parameters'],
    },
    'logRefund': {
      'optional': ['currency', 'coupon', 'value', 'tax', 'shipping', 'transactionId', 'affiliation', 'items', 'parameters'],
    },
    
    // Configuration methods
    'setUserProperty': {
      'required': ['propertyName'],
      'optional': ['propertyValue'],
    },
    'setAnalyticsCollectionEnabled': {
      'required': ['enabled'],
    },
    'setConsent': {
      'anyOf': ['adStorageConsentGranted', 'analyticsStorageConsentGranted', 'adPersonalizationSignalsConsentGranted', 'adUserDataConsentGranted', 'functionalityStorageConsentGranted', 'personalizationStorageConsentGranted', 'securityStorageConsentGranted'],
      'message': 'At least one consent parameter required',
    },
    'setDefaultEventParameters': {
      'required': ['defaultParameters'],
    },
    'setSessionTimeoutDuration': {
      'anyOf': ['timeoutMilliseconds', 'timeout'],
      'message': 'Either timeoutMilliseconds or timeout parameter required',
    },
    'resetAnalyticsData': {},
    
    // iOS-specific conversion methods
    'initiateOnDeviceConversionMeasurementWithEmailAddress': {
      'required': ['emailAddress'],
    },
    'initiateOnDeviceConversionMeasurementWithPhoneNumber': {
      'required': ['phoneNumber'],
    },
    'initiateOnDeviceConversionMeasurementWithHashedEmailAddress': {
      'required': ['hashedEmailAddress'],
    },
    'initiateOnDeviceConversionMeasurementWithHashedPhoneNumber': {
      'required': ['hashedPhoneNumber'],
    },
  };

  /// Validates that [payload] contains the required parameters for [operation].
  static void validate(String operation, Map<String, dynamic> payload) {
    final rule = validationRules[operation];
    if (rule == null) {
      throw ConfigError('Unknown Firebase Analytics operation: $operation');
    }

    // Check required parameters
    if (rule['required'] != null) {
      List<String> missing = [];
      for (String param in rule['required']) {
        if (payload[param] == null) missing.add(param);
      }
      if (missing.isNotEmpty) {
        throw ConfigError('$operation requires: ${missing.join(', ')}');
      }
    }

    // Check "any of" requirements (for operations like setConsent)
    if (rule['anyOf'] != null) {
      bool hasAny = false;
      for (String param in rule['anyOf']) {
        if (payload[param] != null) {
          hasAny = true;
          break;
        }
      }
      if (!hasAny) {
        throw ConfigError(rule['message'] ?? '$operation requires at least one parameter from: ${rule['anyOf'].join(', ')}');
      }
    }
  }
}

/// Analytics SDK operations that do not require a separate value parameter.
enum NoValueOperations {
  /// Displays a configured in-app message without requiring an additional value.
  showInApp,
  /// Displays a configured nudge message without requiring an additional value.
  showNudge,
  /// Resets the analytics or engagement SDK context.
  resetContext,
  /// Sets SDK context from the provided action payload.
  setContext,
  /// Logs the current user out of the engagement SDK.
  logout,
  /// Deletes the current user profile from the engagement SDK.
  deleteUser,
  /// Enables the engagement SDK at runtime.
  enableSdk,
  /// Disables the engagement SDK at runtime.
  disableSdk,
  /// Turns on data tracking in the engagement SDK.
  enableDataTracking,
  /// Turns off data tracking in the engagement SDK.
  disableDataTracking,
  /// Turns on device identifier tracking.
  enableDeviceIdTracking,
  /// Turns off device identifier tracking.
  disableDeviceIdTracking,
  /// Turns on Android ID tracking.
  enableAndroidIdTracking,
  /// Turns off Android ID tracking.
  disableAndroidIdTracking,
  /// Turns on advertising identifier tracking.
  enableAdIdTracking,
  /// Turns off advertising identifier tracking.
  disableAdIdTracking,
  /// Requests push notification permission through the SDK.
  requestPushPermission,
  /// Tracks an analytics event using the event payload.
  trackEvent,
  /// Registers the device for push notifications.
  registerForPush,
  /// Registers for provisional push authorization on supported platforms.
  registerForProvisionalPush,
  /// Passes a Firebase Cloud Messaging token to the SDK.
  passFCMToken,
  /// Passes an iOS PushKit token to the SDK.
  passPushKitToken,
  /// Passes a Firebase push payload to the SDK for processing.
  passFCMPushPayload,
  /// Updates the SDK count of permission prompt attempts.
  updatePermissionCount,
  /// Reports the user's push permission response to the SDK.
  pushPermissionResponse,
}

/// Firebase Analytics parameter names recognized by the log-event action.
enum FirebaseParams {
  /// Names the screen for Firebase Analytics screen_view events.
  screenName,
  /// Identifies the screen class for Firebase Analytics screen tracking.
  screenClass,
  
  /// Records the sign-in method used by a login event.
  loginMethod,
  /// Records the registration method used by a sign-up event.
  signUpMethod,
  
  /// Describes the type of content involved in the event.
  contentType,
  /// Identifies the item involved in a content or commerce event.
  itemId,
  /// Records the method used for sharing, login, signup, or similar events.
  method,
  /// Stores the search query used for a search event.
  searchTerm,
  
  /// Records a game or course level number.
  level,
  /// Records a game character selected by the user.
  character,
  /// Records a human-readable level name.
  levelName,
  /// Indicates whether the operation represented by the event succeeded.
  success,
  /// Records a score associated with a game or achievement event.
  score,
  /// Identifies an unlocked achievement.
  achievementId,
  /// Names the virtual currency used in a game economy event.
  virtualCurrencyName,
  /// Names the item involved in a commerce or content event.
  itemName,
  
  /// Identifies a group involved in a social event.
  groupId,
  
  /// Specifies the ISO currency code for monetary event values.
  currency,
  /// Stores the numeric value associated with a commerce or conversion event.
  value,
  /// Records the campaign or traffic source.
  source,
  /// Records the marketing medium.
  medium,
  /// Records the campaign name.
  campaign,
  /// Records the paid search term.
  term,
  /// Records campaign content or creative variant.
  content,
  /// Stores the app campaign click identifier.
  aclid,
  /// Stores Firebase campaign parameter cp1.
  cp1,
  
  /// Identifies the advertising platform.
  adPlatform,
  /// Identifies the ad source or network.
  adSource,
  /// Identifies the ad format such as banner, interstitial, or rewarded.
  adFormat,
  /// Names the ad unit associated with an ad event.
  adUnitName,
  
  /// Records the coupon code used in a purchase or checkout event.
  coupon,
  /// Records the payment method selected by the user.
  paymentType,
  /// Records the shipping option selected by the user.
  shippingTier,
  /// Contains the Firebase Analytics item list for commerce events.
  items,
  /// Records the tax amount for a purchase event.
  tax,
  /// Records the shipping amount for a purchase event.
  shipping,
  /// Identifies a purchase or refund transaction.
  transactionId,
  /// Records the store or affiliation for a commerce event.
  affiliation,
  /// Identifies the list that presented commerce items.
  itemListId,
  /// Names the list that presented commerce items.
  itemListName,
  /// Names the creative used in a promotion event.
  creativeName,
  /// Identifies the placement slot for a promotion creative.
  creativeSlot,
  /// Identifies a physical or logical location for the event.
  locationId,
  /// Identifies a promotion shown to the user.
  promotionId,
  /// Names a promotion shown to the user.
  promotionName,
  
  /// Names a user property being set or cleared.
  propertyName,
  /// Stores the value assigned to a user property.
  propertyValue,
  /// Controls whether analytics collection is enabled.
  enabled,
  /// Reports consent for advertising storage.
  adStorageConsentGranted,
  /// Reports consent for analytics storage.
  analyticsStorageConsentGranted,
  /// Reports consent for ad personalization signals.
  adPersonalizationSignalsConsentGranted,
  /// Reports consent for advertising user data.
  adUserDataConsentGranted,
  /// Provides default parameters attached to future analytics events.
  defaultParameters,
  /// Configures an operation timeout in milliseconds.
  timeoutMilliseconds,
  /// Configures an operation timeout value.
  timeout,
  
  /// Passes an email address for iOS conversion tracking when supported.
  emailAddress,
  /// Passes a phone number for iOS conversion tracking when supported.
  phoneNumber,
  /// Passes a hashed email address for privacy-preserving conversion tracking.
  hashedEmailAddress,
  /// Passes a hashed phone number for privacy-preserving conversion tracking.
  hashedPhoneNumber,
}
