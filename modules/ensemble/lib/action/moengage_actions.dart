import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/moengage_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moengage_flutter/moengage_flutter.dart';

// Main action types available for MoEngage
enum MoEngageActionType {
  // User attributes
  setUser, // Generic action to set any user attribute

  // Events
  trackEvent,

  // App State
  appConfig,

  // Push/Notification
  pushConfig,

  // InApp & Cards
  displayConfig
}

// Sub-types for setUser action
enum MoEngageUserAttributeType {
  uniqueId,
  userName,
  firstName,
  lastName,
  email,
  mobile,
  gender,
  birthday,
  location,
  alias,
  custom, // For custom attribute with key-value
  timestamp,
  locationAttribute
}

// Sub-types for app configuration
enum MoEngageAppConfigType {
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
  setAppStatus,
  logout,
  deleteUser
}

// Sub-types for push notification configuration
enum MoEngagePushConfigType {
  registerForPush,
  registerForProvisionalPush,
  passFCMToken,
  passPushKitToken,
  passFCMPushPayload,
  requestPushPermission,
  updatePermissionCount,
  pushPermissionResponse
}

// Sub-types for display configuration
enum MoEngageDisplayConfigType {
  showInApp,
  showNudge,
  setContext,
  resetContext
}

class MoEngageAction extends EnsembleAction {
  final MoEngageActionType? type;
  final dynamic actionType; // Sub type enum based on main type
  final dynamic value;
  final Map<String, dynamic>? properties; // For events and custom attributes
  final String? attributeKey; // For custom user attributes
  final EnsembleAction? onSuccess;
  final EnsembleAction? onError;

  MoEngageAction(
      {super.initiator,
      required this.type,
      this.actionType,
      this.value,
      this.properties,
      this.attributeKey,
      this.onSuccess,
      this.onError});

  factory MoEngageAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null || payload['type'] == null) {
      throw ConfigError('MoEngage action requires type');
    }

    return MoEngageAction(
        initiator: initiator,
        type: MoEngageActionType.values.from(payload['type']) ?? null,
        actionType: _getSubType(payload['type'], payload['actionType']),
        value: payload['value'],
        properties: Utils.getMap(payload['properties']),
        attributeKey: Utils.optionalString(payload['attributeKey']),
        onSuccess: EnsembleAction.from(payload['onSuccess']),
        onError: EnsembleAction.from(payload['onError']));
  }

  static dynamic _getSubType(String mainType, String? subType) {
    if (subType == null) return null;

    switch (MoEngageActionType.values.from(mainType)) {
      case MoEngageActionType.setUser:
        return MoEngageUserAttributeType.values.from(subType);
      case MoEngageActionType.appConfig:
        return MoEngageAppConfigType.values.from(subType);
      case MoEngageActionType.pushConfig:
        return MoEngagePushConfigType.values.from(subType);
      case MoEngageActionType.displayConfig:
        return MoEngageDisplayConfigType.values.from(subType);
      default:
        return null;
    }
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      final moEngage = GetIt.instance<MoEngageModule>();
      final evaluatedValue = scopeManager.dataContext.eval(value);

      if (type == null) {
        throw ConfigError('MoEngage action requires a valid type');
      }
      print(type);

      switch (type!) {
        case MoEngageActionType.setUser:
          await _handleUserAttribute(moEngage, evaluatedValue);
          break;

        case MoEngageActionType.trackEvent:
          await _handleTrackEvent(moEngage, evaluatedValue);
          break;

        case MoEngageActionType.appConfig:
          await _handleAppConfig(moEngage, evaluatedValue);
          break;

        case MoEngageActionType.pushConfig:
          await _handlePushConfig(moEngage, evaluatedValue);
          break;

        case MoEngageActionType.displayConfig:
          await _handleDisplayConfig(moEngage, evaluatedValue);
          break;
      }

      if (onSuccess != null) {
        ScreenController().executeAction(context, onSuccess!);
      }
    } catch (error) {
      if (onError != null) {
        ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(null, error: error.toString()));
      } else {
        rethrow;
      }
    }
  }

  Future<void> _handleUserAttribute(
      MoEngageModule moEngage, dynamic value) async {
    
    if (value == null) {
      throw ConfigError('User attribute value cannot be null');
    }

    // Check attributeKey for types that require it
    if ((actionType == MoEngageUserAttributeType.custom || 
         actionType == MoEngageUserAttributeType.timestamp ||
         actionType == MoEngageUserAttributeType.locationAttribute) && 
        (attributeKey == null || attributeKey!.isEmpty)) {
      throw ConfigError('Attribute key is required for ${actionType.name}');
    }

    switch (actionType as MoEngageUserAttributeType) {
      case MoEngageUserAttributeType.uniqueId:
        await moEngage.setUniqueId(Utils.getString(value, fallback: ''));
        break;

      case MoEngageUserAttributeType.userName:
        await moEngage.setUserName(Utils.getString(value, fallback: ''));
        break;

      case MoEngageUserAttributeType.firstName:
        await moEngage.setFirstName(Utils.getString(value, fallback: ''));
        break;

      case MoEngageUserAttributeType.lastName:
        await moEngage.setLastName(Utils.getString(value, fallback: ''));
        break;

      case MoEngageUserAttributeType.email:
        await moEngage.setEmail(Utils.getString(value, fallback: ''));
        break;

      case MoEngageUserAttributeType.mobile:
        await moEngage.setPhoneNumber(Utils.getString(value, fallback: ''));
        break;

      case MoEngageUserAttributeType.gender:
        await moEngage
            .setGender(MoEGender.values.from(value) ?? MoEGender.male);
        break;

      case MoEngageUserAttributeType.birthday:
        await moEngage.setBirthDate(Utils.getString(value, fallback: ''));
        break;

      case MoEngageUserAttributeType.location:
        final location = getLocation(value);
        if (location != null) {
          await moEngage.setLocation(location);
        }
        break;

      case MoEngageUserAttributeType.alias:
        await moEngage.setAlias(Utils.getString(value, fallback: ''));
        break;

      case MoEngageUserAttributeType.custom:
        await moEngage.setUserAttribute(attributeKey!, value);
        break;

      case MoEngageUserAttributeType.timestamp:
        await moEngage.setUserAttributeIsoDate(
          attributeKey!, 
          Utils.getString(value, fallback: '')
        );
        break;

      case MoEngageUserAttributeType.locationAttribute:
        final location = getLocation(value);
        if (location != null) {
          await moEngage.setUserAttributeLocation(attributeKey!, location);
        }
        break;
    }
  }

  Future<void> _handleTrackEvent(
      MoEngageModule moEngage, String eventName) async {
    if (properties != null) {
      final moEProperties = MoEProperties();
      properties!.forEach((key, value) {
        moEProperties.addAttribute(key, value);
      });
      await moEngage.trackEvent(eventName, moEProperties);
    } else {
      await moEngage.trackEvent(eventName);
    }
  }

  Future<void> _handleAppConfig(MoEngageModule moEngage, dynamic value) async {
    switch (actionType as MoEngageAppConfigType) {
      case MoEngageAppConfigType.enableSdk:
        await moEngage.enableSdk();
        break;
      case MoEngageAppConfigType.disableSdk:
        await moEngage.disableSdk();
        break;
      case MoEngageAppConfigType.enableDataTracking:
        await moEngage.enableDataTracking();
        break;
      case MoEngageAppConfigType.disableDataTracking:
        await moEngage.disableDataTracking();
        break;
      case MoEngageAppConfigType.enableDeviceIdTracking:
        await moEngage.enableDeviceIdTracking();
        break;
      case MoEngageAppConfigType.disableDeviceIdTracking:
        await moEngage.disableDeviceIdTracking();
        break;
      case MoEngageAppConfigType.enableAndroidIdTracking:
        await moEngage.enableAndroidIdTracking();
        break;
      case MoEngageAppConfigType.disableAndroidIdTracking:
        await moEngage.disableAndroidIdTracking();
        break;
      case MoEngageAppConfigType.enableAdIdTracking:
        await moEngage.enableAdIdTracking();
        break;
      case MoEngageAppConfigType.disableAdIdTracking:
        await moEngage.disableAdIdTracking();
        break;
      case MoEngageAppConfigType.setAppStatus:
        await moEngage.setAppStatus(MoEAppStatus.values.from(value)!);
        break;
      case MoEngageAppConfigType.logout:
        await moEngage.logout();
        break;
      case MoEngageAppConfigType.deleteUser:
        await moEngage.deleteUser();
        break;
    }
  }

  Future<void> _handlePushConfig(MoEngageModule moEngage, dynamic value) async {
    switch (actionType as MoEngagePushConfigType) {
      case MoEngagePushConfigType.registerForPush:
        await moEngage.registerForPushNotification();
        break;
      case MoEngagePushConfigType.registerForProvisionalPush:
        await moEngage.registerForProvisionalPush();
        break;
      case MoEngagePushConfigType.passFCMToken:
        await moEngage.passFCMPushToken(value.toString());
        break;
      case MoEngagePushConfigType.passPushKitToken:
        await moEngage.passPushKitPushToken(value.toString());
        break;
      case MoEngagePushConfigType.passFCMPushPayload:
        await moEngage.passFCMPushPayload(Map<String, String>.from(value));
        break;
      case MoEngagePushConfigType.requestPushPermission:
        await moEngage.requestPushPermissionAndroid();
        break;
      case MoEngagePushConfigType.updatePermissionCount:
        await moEngage.updatePushPermissionRequestCountAndroid(value);
        break;
      case MoEngagePushConfigType.pushPermissionResponse:
        await moEngage.pushPermissionResponseAndroid(value);
        break;
    }
  }

  Future<void> _handleDisplayConfig(
      MoEngageModule moEngage, dynamic value) async {
    switch (actionType as MoEngageDisplayConfigType) {
      case MoEngageDisplayConfigType.showInApp:
        await moEngage.showInApp();
        break;
      case MoEngageDisplayConfigType.showNudge:
        await moEngage.showNudge(
            position: MoEngageNudgePosition.values.from(value)!);
        break;
      case MoEngageDisplayConfigType.setContext:
        await moEngage.setCurrentContext(List<String>.from(value));
        break;
      case MoEngageDisplayConfigType.resetContext:
        await moEngage.resetCurrentContext();
        break;
    }
  }

  static MoEGeoLocation? getLocation(dynamic value) {
    if (value is Map) {
      final lat = Utils.getDouble(value['latitude'], fallback: 0);
      final lng = Utils.getDouble(value['longitude'], fallback: 0);
      return MoEGeoLocation(lat, lng);
    }
    
    final locationData = Utils.getLatLng(value);
    if (locationData != null) {
      return MoEGeoLocation(locationData.latitude, locationData.longitude);
    }
    return null;
  }
}
