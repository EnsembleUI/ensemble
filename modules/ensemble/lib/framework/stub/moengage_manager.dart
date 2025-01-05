import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/util/moengage_utils.dart';

typedef NotificationCallback = void Function(dynamic data);

abstract class MoEngageModule {
  // Initialization
  Future<void> initialize(String workspaceId, {bool enableLogs = false});
  
  // Event Tracking  
  Future<void> trackEvent(String eventName, [EnsembleProperties? properties]);

  // User Attributes - Basic
  Future<void> setUniqueId(String uniqueId);
  Future<void> setUserName(String userName);
  Future<void> setFirstName(String firstName);
  Future<void> setLastName(String lastName);
  Future<void> setEmail(String email);
  Future<void> setPhoneNumber(String phoneNumber);
  Future<void> setGender(EnsembleGender gender);
  Future<void> setBirthDate(String birthDate);
  Future<void> setLocation(EnsembleGeoLocation location);
  Future<void> setAlias(String alias);

  // User Attributes - Custom
  Future<void> setUserAttribute(String attributeName, dynamic value);
  Future<void> setUserAttributeIsoDate(String attributeName, String date);
  Future<void> setUserAttributeLocation(String attributeName, EnsembleGeoLocation location);

  // App Status & Tracking
  Future<void> setAppStatus(EnsembleAppStatus status);
  Future<void> enableDataTracking();
  Future<void> disableDataTracking();

  // Device ID Management
  Future<void> enableDeviceIdTracking();
  Future<void> disableDeviceIdTracking();
  Future<void> enableAndroidIdTracking();
  Future<void> disableAndroidIdTracking();
  Future<void> enableAdIdTracking();
  Future<void> disableAdIdTracking();

  // Push Notifications
  Future<void> registerForPushNotification();
  Future<void> registerForProvisionalPush();
  Future<void> passFCMPushToken(String token);
  Future<void> passPushKitPushToken(String token);
  Future<void> passFCMPushPayload(Map<String, String> payload);
  Future<void> requestPushPermissionAndroid();
  Future<void> updatePushPermissionRequestCountAndroid(int count);
  Future<void> pushPermissionResponseAndroid(bool granted);

  // InApp & Context
  Future<void> showInApp();
  Future<void> showNudge({EnsembleNudgePosition position = EnsembleNudgePosition.bottom});
  Future<void> setCurrentContext(List<String> contexts);
  Future<void> resetCurrentContext();
  Future<void> getSelfHandledInApp();
  Future<void> selfHandledShown(dynamic data);
  Future<void> selfHandledClicked(dynamic data);
  Future<void> selfHandledDismissed(dynamic data);

  // Lifecycle
  Future<void> onOrientationChanged();

  // Handlers
  void setPushClickCallbackHandler(NotificationCallback handler);
  void setPushTokenCallbackHandler(NotificationCallback handler);
  void setInAppShownCallbackHandler(NotificationCallback handler);
  void setInAppDismissedCallbackHandler(NotificationCallback handler);
  void setSelfHandledInAppHandler(NotificationCallback handler);

  // SDK Control
  Future<void> enableSdk();
  Future<void> disableSdk();
  Future<void> logout();
  Future<bool> deleteUser();
}

class MoEngageModuleStub implements MoEngageModule {
  final _errorMsg = "MoEngage module is not enabled. Please review the Ensemble documentation.";
  
  MoEngageModuleStub() {}

  @override
  Future<void> initialize(String workspaceId, {bool enableLogs = false}) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> trackEvent(String eventName, [EnsembleProperties? properties]) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setUniqueId(String uniqueId) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setUserName(String userName) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setFirstName(String firstName) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setLastName(String lastName) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setEmail(String email) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setPhoneNumber(String phoneNumber) {
    throw ConfigError(_errorMsg);
  }

  @override 
  Future<void> setGender(EnsembleGender gender) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setBirthDate(String birthDate) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setLocation(EnsembleGeoLocation location) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setAlias(String alias) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setUserAttribute(String attributeName, dynamic value) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setUserAttributeIsoDate(String attributeName, String date) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setUserAttributeLocation(String attributeName, EnsembleGeoLocation location) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setAppStatus(EnsembleAppStatus status) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> enableDataTracking() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> disableDataTracking() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> enableDeviceIdTracking() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> disableDeviceIdTracking() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> enableAndroidIdTracking() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> disableAndroidIdTracking() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> enableAdIdTracking() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> disableAdIdTracking() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> registerForPushNotification() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> registerForProvisionalPush() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> passFCMPushToken(String token) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> passPushKitPushToken(String token) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> passFCMPushPayload(Map<String, String> payload) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> requestPushPermissionAndroid() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> updatePushPermissionRequestCountAndroid(int count) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> pushPermissionResponseAndroid(bool granted) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> showInApp() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> showNudge({EnsembleNudgePosition position = EnsembleNudgePosition.bottom}) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setCurrentContext(List<String> contexts) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> resetCurrentContext() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> getSelfHandledInApp() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> selfHandledShown(data) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> selfHandledClicked(data) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> selfHandledDismissed(data) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> onOrientationChanged() {
    throw ConfigError(_errorMsg);
  }

  @override
  void setPushClickCallbackHandler(NotificationCallback handler) {
    throw ConfigError(_errorMsg);
  }

  @override
  void setPushTokenCallbackHandler(NotificationCallback handler) {
    throw ConfigError(_errorMsg);
  }

  @override
  void setInAppShownCallbackHandler(NotificationCallback handler) {
    throw ConfigError(_errorMsg);
  }

  @override
  void setInAppDismissedCallbackHandler(NotificationCallback handler) {
    throw ConfigError(_errorMsg);
  }

  @override
  void setSelfHandledInAppHandler(NotificationCallback handler) {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> enableSdk() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> disableSdk() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> logout() {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<bool> deleteUser() {
    throw ConfigError(_errorMsg);
  }
}