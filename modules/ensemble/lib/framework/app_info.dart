import 'dart:core';
import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_provider.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfo with Invokable, AppInfoCapability {
  static final AppInfo _instance = AppInfo._internal();
  AppInfo._internal();
  factory AppInfo() {
    return _instance;
  }

  @override
  Map<String, Function> getters() {
    return {
      'appId': () => appId,
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

/// retrieve basic app info
mixin AppInfoCapability {
  PackageInfo? _info;
  String? _appId;

  PackageInfo? get info => _info;
  String? get appId => _appId;

  /// initialize package info
  void initPackageInfo(EnsembleConfig? config) async {
    try {
      if (config?.definitionProvider is EnsembleDefinitionProvider) {
        _appId = (config?.definitionProvider as EnsembleDefinitionProvider?)
            ?.appModel
            .appId;
      }
      _info = await PackageInfo.fromPlatform();
    } catch (e) {
      log("Error getting package info: $e");
    }
  }
}
