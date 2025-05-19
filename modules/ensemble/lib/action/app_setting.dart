import 'dart:developer';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:open_settings_plus/open_settings_plus.dart';

// Enums for Android platform
enum AndroidSettingsTarget {
  settings,
  notification,
  accessibility,
  apn,
  batteryOptimization,
  bluetooth,
  dataRoaming,
  date,
  developer,
  device,
  display,
  internalStorage,
  location,
  lockAndPassword,
  nfc,
  security,
  sound,
  wifi,
  appSettings,
  memoryCard,
  addAccount,
  airplaneMode,
  applicationDetails,
  applicationNotification,
  applicationSettings,
  applicationWriteSettings,
  batterySaver,
  captioning,
  cast,
  dataUsage,
  appNotificationBubble,
  appNotification,
  search,
  biometricEnroll,
  hardwareKeyboard,
  home,
  ignoreBackgroundDataRestrictions,
  inputMethod,
  inputMethodSubtype,
  locale,
  manageAllApplications,
  manageApplication,
  manageDefaultApps,
  manageExternalSources,
  manageOverlay
}

// Enums for iOS platform
enum IOSSettingsTarget {
  settings,
  wifi,
  accessibility,
  bluetooth,
  date,
  display,
  sound,
  location,
  security,
  hotspot,
  icloud,
  privacy,
  cellular,
  siri,
  photos,
  keyboard,
  general,
  appSettings,
  about,
  accountSettings,
  autoLock,
  battery,
  dictionary,
  facetime,
  healthKit,
  music,
  keyboards,
  languageAndRegion,
  phone,
  profilesAndDeviceManagement,
  softwareUpdate,
  storageAndBackup,
  wallpapers
}

class AppSettingAction extends EnsembleAction {
  AppSettingAction({
    super.initiator,
    required this.target,
  });

  final String target;

  String getTarget(dataContext) =>
      dataContext.eval(target) ?? 'settings';

  factory AppSettingAction.from({Invokable? initiator, Map? payload}) {
    return AppSettingAction(
      initiator: initiator,
      target: Utils.getString(payload?['target'], fallback: 'settings'),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    final settingTarget = getTarget(scopeManager.dataContext).toLowerCase();
    openAppSettings(settingTarget);
    return Future.value(null);
  }

  // Static method that can be used by both AppSettingAction and Device class
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