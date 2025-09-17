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

class LogEvent extends ensembleAction.EnsembleAction {
  final String? eventName;
  final Map<dynamic, dynamic>? parameters;
  final String? provider;
  final String? operation;
  final String? userId;
  final String logLevel;
  final dynamic value;
  final String? attributeKey;
  final Map? originalPayload;
  final ensembleAction.EnsembleAction? onSuccess;
  final ensembleAction.EnsembleAction? onError;

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
        case 'locationAttribute':
          final location = EnsembleGeoLocation.parse(value);
          if (location == null) {
            throw LanguageError('Invalid location format');
          }
          break;

        case 'custom':
        case 'timestamp':
        case 'locationAttribute':
          if (attributeKey == null) {
            throw LanguageError('Operation $operation requires attributeKey');
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
class FirebaseAnalyticsValidator {
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
      'optional': ['screenClass'],
    },
    
    // User lifecycle
    'logLogin': {
      'optional': ['loginMethod'],
    },
    'logSignUp': {
      'required': ['signUpMethod'],
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

// Operations that don't require value parameter
enum NoValueOperations {
  showInApp,
  showNudge,
  resetContext,
  setContext,
  logout,
  deleteUser,
  enableSdk,
  disableSdk,
  enableDataTracking,
  disableDataTracking,
  enableDeviceIdTracking,
  disableDeviceIdTracking,
  enableAndroidIdTracking,
  disableAndroidIdTracking,
  enableAdIdTracking,
  disableAdIdTracking,
  requestPushPermission,
  trackEvent,
  registerForPush,
  registerForProvisionalPush,
  passFCMToken,
  passPushKitToken,
  passFCMPushPayload,
  updatePermissionCount,
  pushPermissionResponse,
}

// Firebase-specific parameters enum
enum FirebaseParams {
  // Screen tracking
  screenName,
  screenClass,
  
  // User lifecycle
  loginMethod,
  signUpMethod,
  
  // Content interaction
  contentType,
  itemId,
  method,
  searchTerm,
  
  // Gaming and achievements
  level,
  character,
  levelName,
  success,
  score,
  achievementId,
  virtualCurrencyName,
  itemName,
  
  // Social features
  groupId,
  
  // Commerce
  currency,
  value,
  source,
  medium,
  campaign,
  term,
  content,
  aclid,
  cp1,
  
  // Advertising
  adPlatform,
  adSource,
  adFormat,
  adUnitName,
  
  // E-commerce
  coupon,
  paymentType,
  shippingTier,
  items,
  tax,
  shipping,
  transactionId,
  affiliation,
  itemListId,
  itemListName,
  creativeName,
  creativeSlot,
  locationId,
  promotionId,
  promotionName,
  
  // Configuration
  propertyName,
  propertyValue,
  enabled,
  adStorageConsentGranted,
  analyticsStorageConsentGranted,
  adPersonalizationSignalsConsentGranted,
  adUserDataConsentGranted,
  defaultParameters,
  timeoutMilliseconds,
  timeout,
  
  // iOS conversion tracking
  emailAddress,
  phoneNumber,
  hashedEmailAddress,
  hashedPhoneNumber,
}
