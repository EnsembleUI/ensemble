import 'package:moengage_flutter_platform_interface/moengage_flutter_platform_interface.dart';
// import './model//moe_init_config.dart'?

/// Helper Class to interact with MoEngage SDK
class MoEngageFlutter {
  /// [MoEngageFlutter] Constructor
  MoEngageFlutter(this.appId, {MoEInitConfig? moEInitConfig})
      : _moEInitConfig = moEInitConfig ?? MoEInitConfig.defaultConfig() {
    //Requires For Setting Up Native to Hybrid Method Channel Callback
    CoreController.init();
  }

  /// MoEngage App ID
  String appId;
  final MoEInitConfig _moEInitConfig;

  MoEngageFlutterPlatform get _platform => MoEngageFlutterPlatform.instance;

  /// Initialize MoEngage SDK
  void initialise() {
    print(appId);
    _platform.initialise(_moEInitConfig, appId);
  }

  /// Sets Push Click Callback Handler
  /// [handler] - Callback of type [PushClickCallbackHandler]
  void setPushClickCallbackHandler(PushClickCallbackHandler? handler) {
    CoreInstanceProvider()
        .getCallbackCacheForInstance(appId)
        .pushClickCallbackHandler = handler;
  }

  /// Sets Push Token Available Callback Handler
  /// [handler] - Callback of type [PushTokenCallbackHandler]
  void setPushTokenCallbackHandler(PushTokenCallbackHandler? handler) {
    Cache().pushTokenCallbackHandler = handler;
  }

  /// Sets InApp Click Callback Listener
  /// [handler] - Callback of type [InAppClickCallbackHandler]
  void setInAppClickHandler(InAppClickCallbackHandler? handler) {
    CoreInstanceProvider()
        .getCallbackCacheForInstance(appId)
        .inAppClickCallbackHandler = handler;
  }

  /// Sets InApp Shown Callback Handler
  /// [handler] - Callback of type [InAppShownCallbackHandler]
  void setInAppShownCallbackHandler(InAppShownCallbackHandler? handler) {
    CoreInstanceProvider()
        .getCallbackCacheForInstance(appId)
        .inAppShownCallbackHandler = handler;
  }

  /// Sets InApp Dismiss Callback Handler
  /// [handler] - Callback of type [InAppDismissedCallbackHandler]
  void setInAppDismissedCallbackHandler(
      InAppDismissedCallbackHandler? handler) {
    CoreInstanceProvider()
        .getCallbackCacheForInstance(appId)
        .inAppDismissedCallbackHandler = handler;
  }

  /// Sets Self Handled Callback Available Handler
  /// [handler] - Callback of type [SelfHandledInAppCallbackHandler]
  void setSelfHandledInAppHandler(SelfHandledInAppCallbackHandler? handler) {
    CoreInstanceProvider()
        .getCallbackCacheForInstance(appId)
        .selfHandledInAppCallbackHandler = handler;
  }

  /// Tracks an event with the given attributes.
  /// [eventName] - Name of the Event to be tracked
  /// [eventAttributes] - Instance of [MoEProperties]
  void trackEvent(String eventName, [MoEProperties? eventAttributes]) {
    eventAttributes ??= MoEProperties();
    _platform.trackEvent(eventName, eventAttributes, appId);
  }

  /// Set a unique identifier for a user.<br/>
  /// [uniqueId] - Unique Identifier of type [String]
  void setUniqueId(String uniqueId) {
    print('Setting Unique Id: $uniqueId');
    print('App Id:  $appId');
    _platform.setUniqueId(uniqueId, appId);
  }

  /// Update user's unique id which was previously set by setUniqueId().
  /// [newUniqueId] - Unique Identifier of type [String]
  void setAlias(String newUniqueId) {
    _platform.setAlias(newUniqueId, appId);
  }

  /// Tracks user-name as a user attribute.
  /// [userName] Full Name value passed by user
  void setUserName(String userName) {
    _platform.setUserName(userName, appId);
  }

  /// Tracks first name as a user attribute.
  /// [firstName] First Name of user passed by user
  void setFirstName(String firstName) {
    _platform.setFirstName(firstName, appId);
  }

  /// Tracks last name as a user attribute.
  /// [lastName] - Last Name of the User
  void setLastName(String lastName) {
    _platform.setLastName(lastName, appId);
  }

  /// Tracks user's email-id as a user attribute.
  /// [emailId] - Email Id of the User
  void setEmail(String emailId) {
    _platform.setEmail(emailId, appId);
  }

  /// Tracks phone number as a user attribute.
  /// [phoneNumber] - Phone Number of the User
  void setPhoneNumber(String phoneNumber) {
    _platform.setPhoneNumber(phoneNumber, appId);
  }

  /// Tracks gender as a user attribute.
  /// [gender] - Instance of [MoEGender]
  void setGender(MoEGender gender) {
    _platform.setGender(gender, appId);
  }

  /// Set's user's location
  /// [location] - Instance of [MoEGeoLocation]
  void setLocation(MoEGeoLocation location) {
    _platform.setLocation(location, appId);
  }

  /// Set user's birth-date.
  /// Birthdate should be sent in the following format - yyyy-MM-dd'T'HH:mm:ss.fff'Z'
  /// [birthDate] - ISO Formatted Date String
  void setBirthDate(String birthDate) {
    _platform.setBirthDate(birthDate, appId);
  }

  /// Tracks a user attribute.
  /// Supported attribute types:
  /// - `String` `int`, `double`, `num`, `bool`
  /// - `List<String>`, `List<int>`, `List<double>`, `List<num>` , List<bool>
  /// - Valid JSON Object with [Map] and Valid JSON Array with [List]
  /// [userAttributeValue] - Data of type [dynamic]
  /// [userAttributeName] - Name of User Attribute
  void setUserAttribute(String userAttributeName, dynamic userAttributeValue) {
    if (userAttributeName.isEmpty) {
      Logger.w('User Attribute Name cannot be empty');
      return;
    }
    final filteredData = filterSupportedTypes(userAttributeValue);
    if (filteredData != null) {
      _platform.setUserAttribute(userAttributeName, filteredData, appId);
    } else {
      Logger.w(
          'Only String, Numbers, Bool, List and JSON Object values are supported as User Attributes, provided name: $userAttributeName, value: $userAttributeValue');
    }
  }

  /// Tracks the given time as user-attribute.<br/>
  /// Date should be passed in the following format - yyyy-MM-dd'T'HH:mm:ss.fff'Z'
  /// [userAttributeName] - Name of User Attribute
  /// [isoDateString] - ISO Formatted Date String
  void setUserAttributeIsoDate(String userAttributeName, String isoDateString) {
    _platform.setUserAttributeIsoDate(userAttributeName, isoDateString, appId);
  }

  /// Tracks the given location as user attribute.
  /// [userAttributeName] - Name of User Attribute
  /// [location] - Instance of [MoEGeoLocation]
  void setUserAttributeLocation(
      String userAttributeName, MoEGeoLocation location) {
    _platform.setUserAttributeLocation(userAttributeName, location, appId);
  }

  /// This API tells the SDK whether it is a fresh install or an existing application was updated.
  /// [appStatus] - Instance of [MoEAppStatus]
  void setAppStatus(MoEAppStatus appStatus) {
    _platform.setAppStatus(appStatus, appId);
  }

  /// Try to show an InApp Message.
  void showInApp() {
    _platform.showInApp(appId);
  }

  /// Invalidates the existing user and session. A new user
  /// and session is created.
  void logout() {
    _platform.logout(appId);
  }

  /// Try to return a self handled in-app to the callback listener.
  /// Ensure self handled in-app listener is set using [setSelfHandledInAppHandler]
  /// before you call this API
  void getSelfHandledInApp() {
    _platform.getSelfHandledInApp(appId);
  }

  /// Mark self-handled campaign as shown.
  /// API to be called only when in-app is self handled
  /// [data] - Instance of [SelfHandledCampaignData]
  void selfHandledShown(SelfHandledCampaignData data) {
    final Map<String, dynamic> payload = InAppPayloadMapper()
        .selfHandleCampaignDataToMap(data, selfHandledActionShown);
    _platform.selfHandledCallback(payload);
  }

  /// Mark self-handled campaign as clicked.
  /// API to be called only when in-app is self handled
  /// [data] - Instance of [SelfHandledCampaignData]
  void selfHandledClicked(SelfHandledCampaignData data) {
    final Map<String, dynamic> payload = InAppPayloadMapper()
        .selfHandleCampaignDataToMap(data, selfHandledActionClick);
    _platform.selfHandledCallback(payload);
  }

  /// Mark self-handled campaign as dismissed.
  /// API to be called only when in-app is self handled
  /// [data] - Instance of [SelfHandledCampaignData]
  void selfHandledDismissed(SelfHandledCampaignData data) {
    final Map<String, dynamic> payload = InAppPayloadMapper()
        .selfHandleCampaignDataToMap(data, selfHandledActionDismissed);
    _platform.selfHandledCallback(payload);
  }

  ///Set the current context for the given user for InApps
  /// [contexts] - [List] of Context
  void setCurrentContext(List<String> contexts) {
    _platform.setCurrentContext(contexts, appId);
  }

  /// Reset Current Context for InApps
  void resetCurrentContext() {
    _platform.resetCurrentContext(appId);
  }

  ///Optionally opt-in data tracking.
  ///Note: By default data tracking is enabled, this API should  be called only
  ///if  you have called [disableDataTracking] at some point.
  void enableDataTracking() {
    _platform.optOutDataTracking(false, appId);
  }

  ///Optionally opt-out of data tracking. When data tracking is opted-out no
  ///event or user attribute is tracked on MoEngage Platform.
  void disableDataTracking() {
    _platform.optOutDataTracking(true, appId);
  }

  /// Push Notification Registration
  /// Note: This API is only for iOS Platform.
  void registerForPushNotification() {
    _platform.registerForPushNotification();
  }

  /// Pass FCM Push Token to the MoEngage SDK.
  /// Note: This API is only for Android Platform.
  /// [pushToken] - FCM Push Token
  void passFCMPushToken(String pushToken) {
    _platform.passPushToken(pushToken, MoEPushService.fcm, appId);
  }

  /// Pass FCM Push Payload to the MoEngage SDK.
  /// Note: This API is only for Android Platform.
  /// [payload] - FCM Push Payload Data
  void passFCMPushPayload(Map<String, dynamic> payload) {
    _platform.passPushPayload(payload, MoEPushService.fcm, appId);
  }

  /// Pass Push Kit Token to the MoEngage SDK.
  /// Note: This API is only for Android Platform.
  /// [pushToken] - Push Kit Token
  void passPushKitPushToken(String pushToken) {
    _platform.passPushToken(pushToken, MoEPushService.push_kit, appId);
  }

  /// API to enable SDK usage.
  /// Note: By default the SDK is enabled, should only be called
  /// if you have called [disableSdk] at some point.
  void enableSdk() {
    _platform.updateSdkState(true, appId);
  }

  /// API to disable all features of the SDK.
  void disableSdk() {
    _platform.updateSdkState(false, appId);
  }

  /// To be called when Orientation of the App Is Changed
  /// Note: This API is only for Android Platform.
  void onOrientationChanged() {
    _platform.onOrientationChanged();
  }

  ///API to enable Android-id tracking
  /// Note: This API is only for Android Platform.
  void enableAndroidIdTracking() {
    _platform.updateDeviceIdentifierTrackingStatus(appId, keyAndroidId, true);
  }

  ///API to enable Android-id tracking.
  ///By default Android-id tracking is disabled, call this method only if you
  ///have called [enableAndroidIdTracking] at some point.
  /// Note: This API is only for Android Platform.
  void disableAndroidIdTracking() {
    _platform.updateDeviceIdentifierTrackingStatus(appId, keyAndroidId, false);
  }

  ///API to enable Advertising Id tracking
  /// Note: This API is only for Android Platform.
  void enableAdIdTracking() {
    _platform.updateDeviceIdentifierTrackingStatus(appId, keyAdId, true);
  }

  ///API to disable Advertising Id tracking.
  ///By default Advertising Id tracking is disabled, call this method only if
  ///you have enabled Advertising Id tracking at some point
  /// Note: This API is only for Android Platform.
  void disableAdIdTracking() {
    _platform.updateDeviceIdentifierTrackingStatus(appId, keyAdId, false);
  }

  ///API to create notification channels on Android.
  /// Note: This API is only for Android Platform.
  void setupNotificationChannelsAndroid() {
    _platform.setupNotificationChannel();
  }

  /// Notify the SDK on notification permission granted state to the application
  /// true if  granted, else false
  /// Note: This API is only for Android Platform.
  /// [isGranted] - Push Permission Granted Flag
  void pushPermissionResponseAndroid(bool isGranted) {
    _platform.permissionResponse(isGranted, PermissionType.PUSH);
  }

  /// Navigates the user to the Notification settings on Android 8 or above,
  /// on older versions the user is navigated the application settings or
  /// application info screen.
  /// Note: This API is only for Android Platform.
  void navigateToSettingsAndroid() {
    _platform.navigateToSettings();
  }

  /// Requests the push permission on Android 13 and above.
  /// Note: This API is only for Android Platform.
  void requestPushPermissionAndroid() {
    _platform.requestPushPermission();
  }

  /// Setup a callback handler for getting the response permission
  /// [handler] - Instance of [PermissionResultCallbackHandler]
  void setPermissionCallbackHandler(PermissionResultCallbackHandler? handler) {
    Cache().permissionResultCallbackHandler = handler;
  }

  /// Configure MoEngage SDK Logs
  /// [logLevel] - [LogLevel] for SDK logs
  /// [isEnabledForReleaseBuild] If true, logs will be printed for the Release build. By default the logs are disabled for the Release build.
  void configureLogs(LogLevel logLevel,
      {bool isEnabledForReleaseBuild = false}) {
    Logger.configureLogs(logLevel, isEnabledForReleaseBuild);
  }

  /// Updates the number of the times Notification permission is requested
  /// Note: This API is only applicable for Android Platform. This should not called in App/Widget lifecycle methods.
  /// [requestCount] This count will be incremented to existing value
  void updatePushPermissionRequestCountAndroid(int requestCount) {
    _platform.updatePushPermissionRequestCountAndroid(requestCount, appId);
  }

  /// Enable Device-id tracking. It is enabled by default, and should be called only if tracking is disabled at some point.
  /// Note: This API is only for Android Platform
  void enableDeviceIdTracking() {
    _platform.updateDeviceIdentifierTrackingStatus(appId, keyDeviceId, true);
  }

  /// Disables Device-id tracking
  /// Note: This API is only for Android Platform
  void disableDeviceIdTracking() {
    _platform.updateDeviceIdentifierTrackingStatus(appId, keyDeviceId, false);
  }

  /// Delete Current User Data From MoEngage Server
  /// Note: This API is only applicable for Android Platform
  /// @returns - Instance of [Future] of type [UserDeletionData]
  /// @since 6.1.0
  Future<UserDeletionData> deleteUser() {
    return _platform.deleteUser(appId);
  }

  /// Show Non-Intrusive Nudge InApp
  /// [position] - [MoEngageNudgePosition] Position in which Nudge InApp should
  /// be displayed. If position is not passed, it will take default position
  /// [MoEngageNudgePosition.any]
  /// Note: This API is available for Android/iOS platforms. Not supported in Web Platform
  /// @since 7.0.0
  void showNudge({MoEngageNudgePosition position = MoEngageNudgePosition.any}) {
    _platform.showNudge(position, appId);
  }

  /// Get Multiple Self Handled InApps
  /// @returns - Instance of [Future] of type [SelfHandledCampaignsData]
  /// @since 8.1.0
  Future<SelfHandledCampaignsData> getSelfHandledInApps() {
    return _platform.getSelfHandledInApps(appId);
  }

  /// Register for Provisional Push Notification
  /// Note: This API is only for iOS Platform.
  /// @since 8.1.0
  void registerForProvisionalPush() {
    _platform.registerForProvisionalPush();
  }
}
