import 'package:ensemble/action/get_network_info_action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:flutter/foundation.dart';

abstract class NetworkInfoManager {
  Future<LocationPermissionStatus> checkPermission();
  Future<String> getLocationStatus();
  Future<InvokableNetworkInfo> getNetworkInfo();
}

class NetworkInfoManagerStub implements NetworkInfoManager {
  NetworkInfoManagerStub() {}
  @override
  Future<InvokableNetworkInfo> getNetworkInfo() {
    if (kIsWeb) {
      throw ConfigError(
          "NetworkInfo module is not supported on the web. Please review the Ensemble documentation.");
    }
    throw ConfigError(
        "NetworkInfo module is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<LocationPermissionStatus> checkPermission() {
    throw ConfigError(
        "NetworkInfo module is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<String> getLocationStatus() {
    throw ConfigError(
        "NetworkInfo module is not enabled. Please review the Ensemble documentation.");
  }
}
