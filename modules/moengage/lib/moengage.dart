import 'dart:io';

import 'package:ensemble/framework/stub/moengage_manager.dart';
import 'package:ensemble_moengage/moengage_notification_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:moengage_flutter/moengage_flutter.dart' hide LogLevel;
import 'package:moengage_flutter_platform_interface/src/log_level.dart';
import 'package:moengage_cards/moengage_cards.dart';
import 'package:moengage_inbox/moengage_inbox.dart';
import 'package:moengage_geofence/moengage_geofence.dart';

class MoEngageImpl implements MoEngageModule {
  static final MoEngageImpl _instance = MoEngageImpl._internal();
  MoEngageImpl._internal();

  late MoEngageFlutter _moengagePlugin;

  bool _initialized = false;
  String? _workspaceId;

  void _checkInitialization() {
    if (!_initialized) {
      throw StateError('MoEngage: Not initialized. Call initialize() first.');
    }
  }

  factory MoEngageImpl({required String workspaceId, bool enableLogs = false}) {
    if (!_instance._initialized) {
      try {
        // Initialize everything here
        _instance._workspaceId = workspaceId;
        
        // 1. Create plugin instance
        _instance._moengagePlugin = MoEngageFlutter(
          workspaceId,
          moEInitConfig: MoEInitConfig(
            pushConfig: PushConfig(shouldDeliverCallbackOnForegroundClick: true),
            analyticsConfig: AnalyticsConfig(
              shouldTrackUserAttributeBooleanAsNumber: false
            )
          )
        );

        // 2. Configure logs if enabled
        if (enableLogs) {
          _instance._moengagePlugin.configureLogs(LogLevel.VERBOSE);
        }

        // 3. Initialize notification handler
        final notificationHandler = MoEngageNotificationHandler();
        notificationHandler.initialize(_instance._moengagePlugin);

        // 4. Initialize plugin
        _instance._moengagePlugin.initialise();

        // 5. Request push permissions
        _instance._requestInitialPushPermissions();

        _instance._initialized = true;
        debugPrint('MoEngage: Initialization complete');
      } catch (e) {
        debugPrint('MoEngage: Initialization failed: $e');
        rethrow;
      }
    }
    return _instance;
  }

  @override
  Future<void> initialize(String workspaceId, {bool enableLogs = false}) async {
    if (_initialized) {
      debugPrint('MoEngage: Already initialized');
      return;
    }

    try {
      _workspaceId = workspaceId;

      // 1. Create plugin instance
      _moengagePlugin = MoEngageFlutter(workspaceId,
          moEInitConfig: MoEInitConfig(
                  pushConfig:
                      PushConfig(shouldDeliverCallbackOnForegroundClick: true),
                  analyticsConfig: AnalyticsConfig(
                      shouldTrackUserAttributeBooleanAsNumber: false)));

      // 2. Configure logs BEFORE notification handler initialization
       if (enableLogs) {
        _moengagePlugin.configureLogs(LogLevel.VERBOSE);
      }

      // 3. Initialize notification handler BEFORE plugin initialization
      final notificationHandler = MoEngageNotificationHandler();
      await notificationHandler.initialize(_moengagePlugin); // Make this await

      // 4. Initialize plugin after callbacks are registered
      _moengagePlugin.initialise();

      // 5. Request push permissions if needed
      await _requestInitialPushPermissions();

      _initialized = true;
      debugPrint('MoEngage: Initialization complete');
    } catch (e) {
      debugPrint('MoEngage: Initialization failed: $e');
      _initialized = false;
      rethrow;
    }
  }

  Future<void> _requestInitialPushPermissions() async {
  try {
    if (Platform.isIOS) {
      // First request Firebase permission
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Only register with MoEngage if permission granted
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
         _moengagePlugin.registerForPushNotification();
      }
    } else if (Platform.isAndroid) {
      // Android 13+ needs runtime permission
       _moengagePlugin.requestPushPermissionAndroid();
    }
  } catch (e) {
    debugPrint('MoEngage: Error requesting push permissions: $e');
  }
}

  @override
  Future<void> trackEvent(String eventName, [MoEProperties? properties]) async {
    _checkInitialization();
    _moengagePlugin.trackEvent(eventName, properties);
  }

  @override
  Future<void> setUniqueId(String uniqueId) async {
    _checkInitialization();
    _moengagePlugin.setUniqueId(uniqueId);
  }

  @override
  Future<void> setUserName(String userName) async {
    print(userName);
    _checkInitialization();
    _moengagePlugin.setUserName(userName);
  }

  @override
  Future<void> setFirstName(String firstName) async {
    _checkInitialization();
    _moengagePlugin.setFirstName(firstName);
  }

  @override
  Future<void> setLastName(String lastName) async {
    _checkInitialization();
    _moengagePlugin.setLastName(lastName);
  }

  @override
  Future<void> setEmail(String email) async {
    _checkInitialization();
    _moengagePlugin.setEmail(email);
  }

  @override
  Future<void> setPhoneNumber(String phoneNumber) async {
    _checkInitialization();
    _moengagePlugin.setPhoneNumber(phoneNumber);
  }

  @override
  Future<void> setGender(MoEGender gender) async {
    _checkInitialization();
    _moengagePlugin.setGender(gender);
  }

  @override
  Future<void> setBirthDate(String birthDate) async {
    _checkInitialization();
    _moengagePlugin.setBirthDate(birthDate);
  }

  @override
  Future<void> setLocation(MoEGeoLocation location) async {
    _checkInitialization();
    _moengagePlugin.setLocation(location);
  }

  @override
  Future<void> setAlias(String alias) async {
    _checkInitialization();
    _moengagePlugin.setAlias(alias);
  }

  @override
  Future<void> setUserAttribute(String attributeName, dynamic value) async {
    _checkInitialization();
    _moengagePlugin.setUserAttribute(attributeName, value);
  }

  @override
  Future<void> setUserAttributeIsoDate(
      String attributeName, String date) async {
    _checkInitialization();
    _moengagePlugin.setUserAttributeIsoDate(attributeName, date);
  }

  @override
  Future<void> setUserAttributeLocation(
      String attributeName, MoEGeoLocation location) async {
    _checkInitialization();
    _moengagePlugin.setUserAttributeLocation(attributeName, location);
  }

  @override
  Future<void> setAppStatus(MoEAppStatus status) async {
    _checkInitialization();
    _moengagePlugin.setAppStatus(status);
  }

  @override
  Future<void> enableDataTracking() async {
    _checkInitialization();
    _moengagePlugin.enableDataTracking();
  }

  @override
  Future<void> disableDataTracking() async {
    _checkInitialization();
    _moengagePlugin.disableDataTracking();
  }

  @override
  Future<void> enableDeviceIdTracking() async {
    _checkInitialization();
    _moengagePlugin.enableDeviceIdTracking();
  }

  @override
  Future<void> disableDeviceIdTracking() async {
    _checkInitialization();
    _moengagePlugin.disableDeviceIdTracking();
  }

  @override
  Future<void> enableAndroidIdTracking() async {
    _checkInitialization();
    _moengagePlugin.enableAndroidIdTracking();
  }

  @override
  Future<void> disableAndroidIdTracking() async {
    _checkInitialization();
    _moengagePlugin.disableAndroidIdTracking();
  }

  @override
  Future<void> enableAdIdTracking() async {
    _checkInitialization();
    _moengagePlugin.enableAdIdTracking();
  }

  @override
  Future<void> disableAdIdTracking() async {
    _checkInitialization();
    _moengagePlugin.disableAdIdTracking();
  }

  @override
  Future<void> registerForPushNotification() async {
    _checkInitialization();
    _moengagePlugin.registerForPushNotification();
  }

  @override
  Future<void> registerForProvisionalPush() async {
    _checkInitialization();
    _moengagePlugin.registerForProvisionalPush();
  }

  @override
  Future<void> passFCMPushToken(String token) async {
    _checkInitialization();
    _moengagePlugin.passFCMPushToken(token);
  }

  @override
  Future<void> passPushKitPushToken(String token) async {
    _checkInitialization();
    _moengagePlugin.passPushKitPushToken(token);
  }

  @override
  Future<void> passFCMPushPayload(Map<String, String> payload) async {
    _checkInitialization();
    _moengagePlugin.passFCMPushPayload(payload);
  }

  @override
  Future<void> requestPushPermissionAndroid() async {
    _checkInitialization();
    _moengagePlugin.requestPushPermissionAndroid();
  }

  @override
  Future<void> updatePushPermissionRequestCountAndroid(int count) async {
    _checkInitialization();
    _moengagePlugin.updatePushPermissionRequestCountAndroid(count);
  }

  @override
  Future<void> pushPermissionResponseAndroid(bool granted) async {
    _checkInitialization();
    _moengagePlugin.pushPermissionResponseAndroid(granted);
  }

  @override
  Future<void> showInApp() async {
    _checkInitialization();
    _moengagePlugin.showInApp();
  }

  @override
  Future<void> showNudge(
      {MoEngageNudgePosition position = MoEngageNudgePosition.bottom}) async {
    _checkInitialization();
    _moengagePlugin.showNudge(position: position);
  }

  @override
  Future<void> setCurrentContext(List<String> contexts) async {
    _checkInitialization();
    _moengagePlugin.setCurrentContext(contexts);
  }

  @override
  Future<void> resetCurrentContext() async {
    _checkInitialization();
    _moengagePlugin.resetCurrentContext();
  }

  @override
  Future<void> getSelfHandledInApp() async {
    _checkInitialization();
    _moengagePlugin.getSelfHandledInApp();
  }

  @override
  Future<void> selfHandledShown(data) async {
    _checkInitialization();
    _moengagePlugin.selfHandledShown(data);
  }

  @override
  Future<void> selfHandledClicked(data) async {
    _checkInitialization();
    _moengagePlugin.selfHandledClicked(data);
  }

  @override
  Future<void> selfHandledDismissed(data) async {
    _checkInitialization();
    _moengagePlugin.selfHandledDismissed(data);
  }

  @override
  Future<void> onOrientationChanged() async {
    _checkInitialization();
    _moengagePlugin.onOrientationChanged();
  }

  @override
  void setPushClickCallbackHandler(NotificationCallback handler) {
    _checkInitialization();
    _moengagePlugin.setPushClickCallbackHandler(handler);
  }

  @override
  void setPushTokenCallbackHandler(NotificationCallback handler) {
    _checkInitialization();
    _moengagePlugin.setPushTokenCallbackHandler(handler);
  }

  @override
  void setInAppShownCallbackHandler(NotificationCallback handler) {
    _checkInitialization();
    _moengagePlugin.setInAppShownCallbackHandler(handler);
  }

  @override
  void setInAppDismissedCallbackHandler(NotificationCallback handler) {
    _checkInitialization();
    _moengagePlugin.setInAppDismissedCallbackHandler(handler);
  }

  @override
  void setSelfHandledInAppHandler(NotificationCallback handler) {
    _checkInitialization();
    _moengagePlugin.setSelfHandledInAppHandler(handler);
  }

  @override
  Future<void> enableSdk() async {
    _checkInitialization();
    _moengagePlugin.enableSdk();
  }

  @override
  Future<void> disableSdk() async {
    _checkInitialization();
    _moengagePlugin.disableSdk();
  }

  @override
  Future<void> logout() async {
    _checkInitialization();
    _moengagePlugin.logout();
  }

  @override
  Future<UserDeletionData> deleteUser() async {
    _checkInitialization();
    return _moengagePlugin.deleteUser();
  }
}
