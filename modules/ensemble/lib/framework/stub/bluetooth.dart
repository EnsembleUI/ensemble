import 'dart:async';

import 'package:ensemble/action/bluetooth_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef AdapterStateCallback = Future<void>? Function(dynamic data);
typedef ScanResultCallback = Future<void>? Function(dynamic data);
typedef ServiceFoundCallback = Future<void>? Function(dynamic data);
typedef DataReceivedCallback = Future<void>? Function(dynamic data);

abstract class BluetoothManager {
  Future<dynamic> startScan({required ScanResultCallback onScanResult});
  Future<void> stopScan();
  void init(
      {required BuildContext context,
      Invokable? initiator,
      EnsembleAction? onDataStream});

  Future<void> turnOn();
  Future<void> connect(String deviceId, ServiceFoundCallback onServiceFound);
  Future<void> subscribe(
      String characteristicId, DataReceivedCallback onDataReceive);
  Future<void> unSubscribe(String characteristicId);

  void dispose() {}

  InvokableBluetooth getInvokableBluetooth();
}

class BluetoothManagerStub implements BluetoothManager {
  BluetoothManagerStub() {}

  @override
  void init({
    required BuildContext context,
    Invokable? initiator,
    EnsembleAction? onDataStream,
  }) {
    if (kIsWeb) {
      throw ConfigError(
          "Bluetooth module is not supported on the web. Please review the Ensemble documentation.");
    }

    throw ConfigError(
        "Bluetooth module is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<dynamic> startScan({required ScanResultCallback onScanResult}) {
    if (kIsWeb) {
      throw ConfigError(
          "Bluetooth module is not supported on the web. Please review the Ensemble documentation.");
    }
    throw ConfigError(
        "Bluetooth module is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<void> turnOn() {
    throw ConfigError(
        "Bluetooth module is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<void> connect(String deviceId, ServiceFoundCallback onServiceFound) {
    throw ConfigError(
        "Bluetooth module is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<void> subscribe(
      String characteristicId, DataReceivedCallback onDataReceive) {
    throw ConfigError(
        "Bluetooth module is not enabled. Please review the Ensemble documentation.");
  }

  @override
  void dispose() {}

  @override
  InvokableBluetooth getInvokableBluetooth() {
    throw ConfigError(
        "Bluetooth module is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<void> stopScan() {
    throw ConfigError(
        "Bluetooth module is not enabled. Please review the Ensemble documentation.");
  }
  
  @override
  Future<void> unSubscribe(String characteristicId) {
    throw ConfigError(
        "Bluetooth module is not enabled. Please review the Ensemble documentation.");
  }
}
