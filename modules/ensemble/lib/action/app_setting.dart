import 'dart:developer';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:open_settings_plus/open_settings_plus.dart';

/// Android settings destinations supported by [AppSettingAction].
enum AndroidSettingsTarget {
  /// Opens the main Android Settings application.
  settings,
  /// Opens Android notification settings.
  notification,
  /// Opens Android accessibility settings.
  accessibility,
  /// Opens Android APN/mobile access point settings.
  apn,
  /// Opens Android battery optimization settings for background behavior.
  batteryOptimization,
  /// Opens Android Bluetooth settings.
  bluetooth,
  /// Opens Android data roaming settings.
  dataRoaming,
  /// Opens Android date and time settings.
  date,
  /// Opens Android developer options.
  developer,
  /// Opens Android device information settings.
  device,
  /// Opens Android display settings.
  display,
  /// Opens Android internal storage settings.
  internalStorage,
  /// Opens Android location settings.
  location,
  /// Opens Android lock screen and password settings.
  lockAndPassword,
  /// Opens Android NFC settings.
  nfc,
  /// Opens Android security settings.
  security,
  /// Opens Android sound settings.
  sound,
  /// Opens Android Wi-Fi settings.
  wifi,
  /// Opens this app's Android settings page.
  appSettings,
  /// Opens Android memory card or storage settings when available.
  memoryCard,
  /// Opens Android account-add flow.
  addAccount,
  /// Opens Android airplane mode settings.
  airplaneMode,
  /// Opens Android application details settings.
  applicationDetails,
  /// Opens notification settings for this Android application.
  applicationNotification,
  /// Opens Android application management settings.
  applicationSettings,
  /// Opens Android write system settings permission page.
  applicationWriteSettings,
  /// Opens Android battery saver settings.
  batterySaver,
  /// Opens Android captioning accessibility settings.
  captioning,
  /// Opens Android cast/screen sharing settings.
  cast,
  /// Opens Android data usage settings.
  dataUsage,
  /// Opens Android notification bubble settings for this app.
  appNotificationBubble,
  /// Opens Android app notification settings.
  appNotification,
  /// Opens Android system search settings.
  search,
  /// Opens Android biometric enrollment settings.
  biometricEnroll,
  /// Opens Android hardware keyboard settings.
  hardwareKeyboard,
  /// Opens Android default home app settings.
  home,
  /// Opens Android unrestricted data access settings.
  ignoreBackgroundDataRestrictions,
  /// Opens Android keyboard/input method settings.
  inputMethod,
  /// Opens Android input method subtype settings.
  inputMethodSubtype,
  /// Opens Android language and locale settings.
  locale,
  /// Opens Android list of all installed applications.
  manageAllApplications,
  /// Opens Android application management settings.
  manageApplication,
  /// Opens Android default apps settings.
  manageDefaultApps,
  /// Opens Android install unknown apps settings.
  manageExternalSources,
  /// Opens Android display-over-other-apps permission settings.
  manageOverlay
}

/// iOS settings destinations supported by [AppSettingAction].
enum IOSSettingsTarget {
  /// Opens the main iOS Settings application.
  settings,
  /// Opens iOS Wi-Fi settings when the platform allows the URL scheme.
  wifi,
  /// Opens iOS accessibility settings.
  accessibility,
  /// Opens iOS Bluetooth settings.
  bluetooth,
  /// Opens iOS date and time settings.
  date,
  /// Opens iOS display settings.
  display,
  /// Opens iOS sound settings.
  sound,
  /// Opens iOS location services settings.
  location,
  /// Opens iOS security or passcode settings when available.
  security,
  /// Opens iOS personal hotspot settings.
  hotspot,
  /// Opens iOS iCloud settings.
  icloud,
  /// Opens iOS privacy settings.
  privacy,
  /// Opens iOS cellular settings.
  cellular,
  /// Opens iOS Siri settings.
  siri,
  /// Opens iOS Photos settings.
  photos,
  /// Opens iOS keyboard settings.
  keyboard,
  /// Opens iOS General settings.
  general,
  /// Opens this app's iOS settings page.
  appSettings,
  /// Opens iOS About settings.
  about,
  /// Opens iOS account settings.
  accountSettings,
  /// Opens iOS auto-lock settings.
  autoLock,
  /// Opens iOS battery settings.
  battery,
  /// Opens iOS dictionary settings.
  dictionary,
  /// Opens iOS FaceTime settings.
  facetime,
  /// Opens iOS Health settings.
  healthKit,
  /// Opens iOS Music settings.
  music,
  /// Opens iOS keyboard list settings.
  keyboards,
  /// Opens iOS language and region settings.
  languageAndRegion,
  /// Opens iOS Phone settings.
  phone,
  /// Opens iOS profiles and device management settings.
  profilesAndDeviceManagement,
  /// Opens iOS software update settings.
  softwareUpdate,
  /// Opens iOS storage settings.
  storageAndBackup,
  /// Opens iOS wallpaper settings.
  wallpapers
}

/// Ensemble action that opens a platform settings screen selected by the YAML payload.
class AppSettingAction extends EnsembleAction {
  /// Creates a [AppSettingAction] action.
  AppSettingAction({
    super.initiator,
    required this.target,
  });

  /// Settings destination requested by the YAML payload.
  final String target;

  /// Evaluates the configured settings target against the current data context.
  String getTarget(dataContext) =>
      dataContext.eval(target) ?? 'settings';

  /// Creates a [AppSettingAction] from a YAML or map action payload.
  factory AppSettingAction.from({Invokable? initiator, Map? payload}) {
    return AppSettingAction(
      initiator: initiator,
      target: Utils.getString(payload?['target'], fallback: 'settings'),
    );
  }

  /// Runs this action and performs the app setting operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    final settingTarget = getTarget(scopeManager.dataContext).toLowerCase();
    openAppSettings(settingTarget);
    return Future.value(null);
  }

  // Static method that can be used by both AppSettingAction and Device class
  /// Opens the requested settings page on the current platform.
  static void openAppSettings(String target) {
    switch (OpenSettingsPlus.shared) {
      case OpenSettingsPlusAndroid android:
        _openAndroidSettings(android, target);
      case OpenSettingsPlusIOS ios:
        _openIOSSettings(ios, target);
      default:
        log('Platform not supported for app settings');
    }
  }

  static void _openAndroidSettings(OpenSettingsPlusAndroid android, String targetStr) {
    final target = AndroidSettingsTarget.values.from(targetStr);
    if (target == null) {
      android(); // Default to main settings
      return;
    }

    switch (target) {
      case AndroidSettingsTarget.settings:
        android();
      case AndroidSettingsTarget.notification:
        android.notification();
      case AndroidSettingsTarget.accessibility:
        android.accessibility();
      case AndroidSettingsTarget.apn:
        android.apnSettings();
      case AndroidSettingsTarget.batteryOptimization:
        android.ignoreBatteryOptimization();
      case AndroidSettingsTarget.bluetooth:
        android.bluetooth();
      case AndroidSettingsTarget.dataRoaming:
        android.dataRoaming();
      case AndroidSettingsTarget.date:
        android.date();
      case AndroidSettingsTarget.developer:
        android.applicationDevelopment();
      case AndroidSettingsTarget.device:
        android.deviceInfo();
      case AndroidSettingsTarget.display:
        android.display();
      case AndroidSettingsTarget.internalStorage:
        android.internalStorage();
      case AndroidSettingsTarget.location:
        android.locationSource();
      case AndroidSettingsTarget.lockAndPassword:
        android.security();
      case AndroidSettingsTarget.nfc:
        android.nfc();
      case AndroidSettingsTarget.security:
        android.security();
      case AndroidSettingsTarget.sound:
        android.sound();
      case AndroidSettingsTarget.wifi:
        android.wifi();
      case AndroidSettingsTarget.appSettings:
        android.appSettings();
      case AndroidSettingsTarget.memoryCard:
        android.memoryCard();
      case AndroidSettingsTarget.addAccount:
        android.addAccount();
      case AndroidSettingsTarget.airplaneMode:
        android.airplaneMode();
      case AndroidSettingsTarget.applicationDetails:
        android.applicationDetails();
      case AndroidSettingsTarget.applicationNotification:
        android.applicationNotification();
      case AndroidSettingsTarget.applicationSettings:
        android.applicationSettings();
      case AndroidSettingsTarget.applicationWriteSettings:
        android.applicationWriteSettings();
      case AndroidSettingsTarget.batterySaver:
        android.batterySaver();
      case AndroidSettingsTarget.captioning:
        android.captioning();
      case AndroidSettingsTarget.cast:
        android.cast();
      case AndroidSettingsTarget.dataUsage:
        android.dataUsage();
      case AndroidSettingsTarget.appNotificationBubble:
        android.appNotificationBubble();
      case AndroidSettingsTarget.appNotification:
        android.appNotification();
      case AndroidSettingsTarget.search:
        android.search();
      case AndroidSettingsTarget.biometricEnroll:
        android.biometricEnroll();
      case AndroidSettingsTarget.hardwareKeyboard:
        android.hardwareKeyboard();
      case AndroidSettingsTarget.home:
        android.home();
      case AndroidSettingsTarget.ignoreBackgroundDataRestrictions:
        android.ignoreBackgroundDataRestrictions();
      case AndroidSettingsTarget.inputMethod:
        android.inputMethod();
      case AndroidSettingsTarget.inputMethodSubtype:
        android.inputMethodSubtype();
      case AndroidSettingsTarget.locale:
        android.locale();
      case AndroidSettingsTarget.manageAllApplications:
        android.manageAllApplications();
      case AndroidSettingsTarget.manageApplication:
        android.manageApplication();
      case AndroidSettingsTarget.manageDefaultApps:
        android.manageDefaultApps();
      case AndroidSettingsTarget.manageExternalSources:
        android.manageExternalSources();
      case AndroidSettingsTarget.manageOverlay:
        android.manageOverlay();
      default:
        android(); // Default to main settings
    }
  }

  static void _openIOSSettings(OpenSettingsPlusIOS ios, String targetStr) {
    final target = IOSSettingsTarget.values.from(targetStr);
    if (target == null) {
      ios(); // Default to main settings
      return;
    }

    switch (target) {
      case IOSSettingsTarget.settings:
        ios();
      case IOSSettingsTarget.accessibility:
        ios.accessibility();
      case IOSSettingsTarget.bluetooth:
        ios.bluetooth();
      case IOSSettingsTarget.cellular:
        ios.cellular();
      case IOSSettingsTarget.date:
        ios.dateAndTime();
      case IOSSettingsTarget.display:
        ios.displayAndBrightness();
      case IOSSettingsTarget.general:
        ios.general();
      case IOSSettingsTarget.hotspot:
        ios.personalHotspot();
      case IOSSettingsTarget.icloud:
        ios.iCloud();
      case IOSSettingsTarget.keyboard:
        ios.keyboard();
      case IOSSettingsTarget.location:
        ios.locationServices();
      case IOSSettingsTarget.photos:
        ios.photosAndCamera();
      case IOSSettingsTarget.privacy:
        ios.privacy();
      case IOSSettingsTarget.security:
        ios.faceIDAndPasscode();
      case IOSSettingsTarget.siri:
        ios.siri();
      case IOSSettingsTarget.sound:
        ios.soundsAndHaptics();
      case IOSSettingsTarget.wifi:
        ios.wifi();
      // Additional iOS settings
      case IOSSettingsTarget.appSettings:
        ios.appSettings();
      case IOSSettingsTarget.about:
        ios.about();
      case IOSSettingsTarget.accountSettings:
        ios.accountSettings();
      case IOSSettingsTarget.autoLock:
        ios.autoLock();
      case IOSSettingsTarget.battery:
        ios.battery();
      case IOSSettingsTarget.dictionary:
        ios.dictionary();
      case IOSSettingsTarget.facetime:
        ios.facetime();
      case IOSSettingsTarget.healthKit:
        ios.healthKit();
      case IOSSettingsTarget.music:
        ios.music();
      case IOSSettingsTarget.keyboards:
        ios.keyboards();
      case IOSSettingsTarget.languageAndRegion:
        ios.languageAndRegion();
      case IOSSettingsTarget.phone:
        ios.phone();
      case IOSSettingsTarget.profilesAndDeviceManagement:
        ios.profilesAndDeviceManagement();
      case IOSSettingsTarget.softwareUpdate:
        ios.softwareUpdate();
      case IOSSettingsTarget.storageAndBackup:
        ios.storageAndBackup();
      case IOSSettingsTarget.wallpapers:
        ios.wallpapers();
      default:
        ios(); // Default to main settings
    }
  }
}