import 'dart:core';
import 'dart:io';
import 'dart:developer';

import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
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

      // Media Query
      "width": () => screenWidth,
      "height": () => screenHeight,
      "safeAreaTop": () => safeAreaTop,
      "safeAreaBottom": () => safeAreaBottom,

      // Misc Info
      "platform": () => platform?.name,
      DevicePlatform.web.name: () => DeviceWebInfo()
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'openAppSettings': (target) => openAppSettings(target),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  void openAppSettings(String target) {
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

  int get screenWidth {
    return _getData().size.width.toInt();
  }

  int get screenHeight {
    return _getData().size.height.toInt();
  }

  int get safeAreaTop {
    return _getData().padding.top.toInt();
  }

  int get safeAreaBottom {
    return _getData().padding.bottom.toInt();
  }
}

/// This mixin can access user's location
mixin LocationCapability {
  static Position? lastLocation;

  Position? getLastLocation() {
    return lastLocation;
  }

  // TODO: shouldn't set this from outside.
  void updateLastLocation(Position location) {
    lastLocation = location;
  }

  Future<LocationStatus> getLocationStatus() async {
    if (await Geolocator.isLocationServiceEnabled()) {
      LocationPermission permission = await Geolocator.checkPermission();
      // ask for permission if not already
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (![LocationPermission.denied, LocationPermission.deniedForever]
          .contains(permission)) {
        return LocationStatus.ready;
      } else {
        return LocationStatus.denied;
      }
    }
    return LocationStatus.disabled;
  }

  Future<DeviceLocation> getLocation() async {
    Position? location;
    LocationStatus status = await getLocationStatus();
    if (status == LocationStatus.ready) {
      location = await simplyGetLocation();
    }
    return DeviceLocation(status: status, location: location);
  }

  /// return the location without any permission checks. Use this only
  /// if you already check for permission with getLocationStatus()
  Future<Position> simplyGetLocation() async {
    lastLocation = await Geolocator.getCurrentPosition();
    return lastLocation!;
  }
}

/// retrieve basic device info
mixin DeviceInfoCapability {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  static DevicePlatform? _platform;
  static WebBrowserInfo? browserInfo;

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
        } else if (Platform.isIOS) {
          _platform = DevicePlatform.ios;
        } else if (Platform.isMacOS) {
          _platform = DevicePlatform.macos;
        } else if (Platform.isWindows) {
          _platform = DevicePlatform.windows;
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
      'languages': () => browserInfo?.languages,
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
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

class Location with Invokable {
  Location(this.location);
  Position? location;

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
      return Geolocator.distanceBetween(
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
  Position? location;
  LocationStatus status;
}

enum LocationStatus {
  ready, // ready to fetch location
  disabled,
  denied,
  unknown
}
