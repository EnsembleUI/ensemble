import 'package:ensemble/framework/action.dart' as ensembleAction;
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
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
// import 'package:moengage_flutter/moengage_flutter.dart';
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
      if (operation == 'logEvent' && eventName == null) {
        throw LanguageError(
            "${ensembleAction.ActionType.logEvent.name} requires the event name");
      } else if (operation == 'setUserId' && payload?['userId'] == null) {
        throw LanguageError(
            "${ensembleAction.ActionType.logEvent.name} requires the user id");
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
      } else if (operation == 'trackPurchase') {
        if (eventName == null) {
          throw LanguageError('trackPurchase requires event name');
        }
      } else if (operation == 'trackProductView') {
        if (eventName == null) {
          throw LanguageError('trackProductView requires event name');
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
        await _handleAdobeOperations(
          context,
          scopeManager,
          operation: scopeManager.dataContext.eval(operation),
          eventName: scopeManager.dataContext.eval(eventName),
          parameters: scopeManager.dataContext.eval(parameters),
          attributeKey: scopeManager.dataContext.eval(attributeKey),
        );

        if (onSuccess != null) {
          await ScreenController().executeAction(context, onSuccess!);
        }
      } else {
        LogManager().log(
          logging.LogType.appAnalytics,
          {
            'name': scopeManager.dataContext.eval(eventName),
            'parameters': scopeManager.dataContext.eval(parameters) ?? {},
            'logLevel':
                stringToLogLevel(scopeManager.dataContext.eval(logLevel)),
            'provider': evaluatedProvider,
            'operation': scopeManager.dataContext.eval(operation),
            'userId': scopeManager.dataContext.eval(userId),
          },
        );
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

Future<void> _handleAdobeOperations(
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
      await adobe.trackAction(
          eventName!,
          parameters!
              .map((key, value) => MapEntry(key.toString(), value.toString())));
      break;
    case 'trackState':
      await adobe.trackState(
          eventName!,
          parameters!
              .map((key, value) => MapEntry(key.toString(), value.toString())));
      break;
    case 'sendEvent':
      await adobe.sendEvent(eventName!, parameters!);
      break;
    default:
      throw LanguageError('Invalid operation: $operation');
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
