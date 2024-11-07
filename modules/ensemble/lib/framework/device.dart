import 'dart:core';
import 'dart:io';
import 'dart:developer';

import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/notification_manager.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

/// get device information as well as requesting device permissions
class Device
    with
        Invokable,
        MediaQueryCapability,
        LocationCapability,
        DeviceInfoCapability {
  static final Device _instance = Device._internal();

  Device._internal();

  factory Device() {
    return _instance;
  }

  @override
  Map<String, Function> getters() {
    return {
      // Capabilities
      'lastLocation': () => Location(getLastLocation()),
      'deviceToken': () => NotificationManager().deviceToken,

      // Media Query
      "width": () => screenWidth,
      "height": () => screenHeight,
      "safeAreaTop": () => safeAreaTop,
      "safeAreaBottom": () => safeAreaBottom,

      // Misc Info
      "platform": () => platform?.name,
      "browserInfo": () => DeviceWebInfo(),
      "androidInfo": () => DeviceAndroidInfo(),
      "iosInfo": () => DeviceIosInfo(),
      "macOsInfo": () => DeviceMacOsInfo(),
      "windowsInfo": () => DeviceWindowsInfo(),

      // @deprecated. backward compatibility
      DevicePlatform.web.name: () => DeviceWebInfo()
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'isIOS': () => platform == DevicePlatform.ios,
      'isAndroid': () => platform == DevicePlatform.android,
      'isWeb': () => platform == DevicePlatform.web,
      'isMacOS': () => platform == DevicePlatform.macos,
      'isWindows': () => platform == DevicePlatform.windows,

      // deprecated. Should be using Action instead
      'openAppSettings': (target) => openAppSettings(target),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  void openAppSettings([String? target]) {
    final settingType =
        AppSettingsType.values.from(target) ?? AppSettingsType.settings;
    AppSettings.openAppSettings(type: settingType);
  }
}

mixin MediaQueryCapability {
  static MediaQueryData? data;

  MediaQueryData _getData() {
    if (StorageManager().isPreview() == true) {
      return MediaQuery.of(Utils.globalAppKey.currentContext!);
    }
    return data ??= MediaQuery.of(Utils.globalAppKey.currentContext!);
  }

  int get screenWidth => _getData().size.width.toInt();
  int get screenHeight => _getData().size.height.toInt();
  int get safeAreaTop => _getData().padding.top.toInt();
  int get safeAreaBottom => _getData().padding.bottom.toInt();
}

/// This mixin can access user's location
mixin LocationCapability {
  static LocationData? lastLocation;

  LocationData? getLastLocation() {
    return lastLocation;
  }

  // TODO: shouldn't set this from outside.
  void updateLastLocation(LocationData location) {
    lastLocation = location;
  }
}

/// retrieve basic device info
mixin DeviceInfoCapability {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static DevicePlatform? _platform;
  static WebBrowserInfo? browserInfo;
  static AndroidDeviceInfo? androidInfo;
  static IosDeviceInfo? iosInfo;
  static MacOsDeviceInfo? macOsInfo;
  static WindowsDeviceInfo? windowsInfo;

  DevicePlatform? get platform => _platform;

  /// initialize device info
  void initDeviceInfo() async {
    try {
      if (kIsWeb) {
        _platform = DevicePlatform.web;
        browserInfo = await _deviceInfoPlugin.webBrowserInfo;
      } else {
        if (Platform.isAndroid) {
          _platform = DevicePlatform.android;
          androidInfo = await _deviceInfoPlugin.androidInfo;
        } else if (Platform.isIOS) {
          _platform = DevicePlatform.ios;
          iosInfo = await _deviceInfoPlugin.iosInfo;
        } else if (Platform.isMacOS) {
          _platform = DevicePlatform.macos;
          macOsInfo = await _deviceInfoPlugin.macOsInfo;
        } else if (Platform.isWindows) {
          _platform = DevicePlatform.windows;
          windowsInfo = await _deviceInfoPlugin.windowsInfo;
        }
      }
    } on PlatformException {
      log("Error getting device info");
    }
  }
}

class DeviceWebInfo with Invokable {
  @override
  Map<String, Function> getters() {
    WebBrowserInfo? browserInfo = DeviceInfoCapability.browserInfo;
    return {
      'browserName': () => browserInfo?.browserName == null
          ? null
          : describeEnum(browserInfo!.browserName),
      'appCodeName': () => browserInfo?.appCodeName,
      'appName': () => browserInfo?.appName,
      'appVersion': () => browserInfo?.appVersion,
      'deviceMemory': () => browserInfo?.deviceMemory,
      'language': () => browserInfo?.language,
      'languages': () => browserInfo?.languages?.join(', '),
      'platform': () => browserInfo?.platform,
      'product': () => browserInfo?.product,
      'productSub': () => browserInfo?.productSub,
      'userAgent': () => browserInfo?.userAgent,
      'vendor': () => browserInfo?.vendor,
      'vendorSub': () => browserInfo?.vendorSub,
      'hardwareConcurrency': () => browserInfo?.hardwareConcurrency,
      'maxTouchPoints': () => browserInfo?.maxTouchPoints,
    };
  }

  @override
  Map<String, Function> methods() => {};
  @override
  Map<String, Function> setters() => {};
}

class DeviceAndroidInfo with Invokable {
  @override
  Map<String, Function> getters() {
    AndroidDeviceInfo? androidInfo = DeviceInfoCapability.androidInfo;
    return {
      'versionRelease': () => androidInfo?.version.release,
      'versionSdkInt': () => androidInfo?.version.sdkInt,
      'versionCodename': () => androidInfo?.version.codename,
      'versionIncremental': () => androidInfo?.version.incremental,
      'versionPreviewSdkInt': () => androidInfo?.version.previewSdkInt,
      'versionSecurityPatch': () => androidInfo?.version.securityPatch,
      'board': () => androidInfo?.board,
      'bootloader': () => androidInfo?.bootloader,
      'brand': () => androidInfo?.brand,
      'device': () => androidInfo?.device,
      'display': () => androidInfo?.display,
      'fingerprint': () => androidInfo?.fingerprint,
      'hardware': () => androidInfo?.hardware,
      'host': () => androidInfo?.host,
      'id': () => androidInfo?.id,
      'manufacturer': () => androidInfo?.manufacturer,
      'model': () => androidInfo?.model,
      'product': () => androidInfo?.product,
      'tags': () => androidInfo?.tags,
      'type': () => androidInfo?.type,
      'isPhysicalDevice': () => androidInfo?.isPhysicalDevice,
      'serialNumber': () => androidInfo?.serialNumber,
    };
  }

  @override
  Map<String, Function> methods() => {};
  @override
  Map<String, Function> setters() => {};
}

class DeviceIosInfo with Invokable {
  @override
  Map<String, Function> getters() {
    IosDeviceInfo? iosInfo = DeviceInfoCapability.iosInfo;
    return {
      'name': () => iosInfo?.name,
      'systemName': () => iosInfo?.systemName,
      'systemVersion': () => iosInfo?.systemVersion,
      'model': () => iosInfo?.model,
      'localizedModel': () => iosInfo?.localizedModel,
      'identifierForVendor': () => iosInfo?.identifierForVendor,
      'isPhysicalDevice': () => iosInfo?.isPhysicalDevice,
      'utsnameSysname': () => iosInfo?.utsname.sysname,
      'utsnameNodename': () => iosInfo?.utsname.nodename,
      'utsnameRelease': () => iosInfo?.utsname.release,
      'utsnameVersion': () => iosInfo?.utsname.version,
      'utsnameMachine': () => iosInfo?.utsname.machine,
    };
  }

  @override
  Map<String, Function> methods() => {};
  @override
  Map<String, Function> setters() => {};
}

class DeviceMacOsInfo with Invokable {
  @override
  Map<String, Function> getters() {
    MacOsDeviceInfo? macOsInfo = DeviceInfoCapability.macOsInfo;
    return {
      'computerName': () => macOsInfo?.computerName,
      'hostName': () => macOsInfo?.hostName,
      'arch': () => macOsInfo?.arch,
      'model': () => macOsInfo?.model,
      'kernelVersion': () => macOsInfo?.kernelVersion,
      'osRelease': () => macOsInfo?.osRelease,
      'majorVersion': () => macOsInfo?.majorVersion,
      'minorVersion': () => macOsInfo?.minorVersion,
      'patchVersion': () => macOsInfo?.patchVersion,
      'activeCPUs': () => macOsInfo?.activeCPUs,
      'memorySize': () => macOsInfo?.memorySize,
      'cpuFrequency': () => macOsInfo?.cpuFrequency,
      'systemGUID': () => macOsInfo?.systemGUID,
    };
  }

  @override
  Map<String, Function> methods() => {};
  @override
  Map<String, Function> setters() => {};
}

class DeviceWindowsInfo with Invokable {
  @override
  Map<String, Function> getters() {
    WindowsDeviceInfo? windowsInfo = DeviceInfoCapability.windowsInfo;
    return {
      'computerName': () => windowsInfo?.computerName,
      'numberOfCores': () => windowsInfo?.numberOfCores,
      'systemMemoryInMegabytes': () => windowsInfo?.systemMemoryInMegabytes,
      'userName': () => windowsInfo?.userName,
      'majorVersion': () => windowsInfo?.majorVersion,
      'minorVersion': () => windowsInfo?.minorVersion,
      'buildNumber': () => windowsInfo?.buildNumber,
      'platformId': () => windowsInfo?.platformId,
      'buildLab': () => windowsInfo?.buildLab,
      'buildLabEx': () => windowsInfo?.buildLabEx,
      'productId': () => windowsInfo?.productId,
      'productName': () => windowsInfo?.productName,
      'releaseId': () => windowsInfo?.releaseId,
      'deviceId': () => windowsInfo?.deviceId,
    };
  }

  @override
  Map<String, Function> methods() => {};
  @override
  Map<String, Function> setters() => {};
}

class Location with Invokable {
  Location(this.location);

  LocationData? location;

  @override
  Map<String, Function> getters() {
    return {
      'latitude': () => location?.latitude,
      'longitude': () => location?.longitude
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'distance': getDistance,
      'formattedDistance': getFormattedDistance,
    };
  }

  /// return distance between 2 coordinates in miles
  double? getDistance(double lat, double lng) {
    if (location != null) {
      return GetIt.I<LocationManager>().distanceBetween(
              location!.latitude, location!.longitude, lat, lng) /
          1609.344;
    }
    return null;
  }

  String getFormattedDistance(double lat, double lng) {
    int? distance = getDistance(lat, lng)?.toInt();
    if (distance != null) {
      return NumberFormat.decimalPattern().format(distance) +
          (distance > 1 ? ' miles' : ' mile');
    }
    return '';
  }
}

enum DevicePlatform { web, android, ios, macos, windows, other }

// the wrapper class for location request that includes other info
class DeviceLocation {
  DeviceLocation({required this.status, this.location});

  LocationData? location;
  LocationStatus status;
}

enum LocationStatus {
  ready, // ready to fetch location
  disabled,
  denied,
  unknown
}
