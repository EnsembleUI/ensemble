import 'dart:core';
import 'dart:developer';

import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Package with Invokable, PackageInfoCapability {
  static final Package _instance = Package._internal();
  Package._internal();
  factory Package() {
    return _instance;
  }

  @override
  Map<String, Function> getters() {
    return {
      'appName': () => info?.appName,
      'packageName': () => info?.packageName,
      'version': () => info?.version,
      'buildNumber': () => info?.buildNumber,
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

/// retrieve basic device info
mixin PackageInfoCapability {
  PackageInfo? _info;

  PackageInfo? get info => _info;

  /// initialize package info
  void initPackageInfo() async {
    try {
      _info = await PackageInfo.fromPlatform();
    } catch (e) {
      log("Error getting package info: $e");
    }
  }
}
