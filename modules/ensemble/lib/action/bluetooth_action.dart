import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/bluetooth.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class InitializeBluetoothAction extends EnsembleAction {
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  EnsembleAction? onError;
  EnsembleAction? onDataStream;

  InitializeBluetoothAction(
      {super.initiator, super.inputs, this.onError, this.onDataStream});

  factory InitializeBluetoothAction.from(
          {Invokable? initiator, dynamic payload}) =>
      InitializeBluetoothAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  factory InitializeBluetoothAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return InitializeBluetoothAction(
      initiator: initiator,
      inputs: Utils.getMap(payload?['inputs']),
      onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
      onDataStream:
          EnsembleAction.from(payload?['onDataStream'], initiator: initiator),
    );
  }

  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    if (kIsWeb && onError != null) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(
            initiator,
            error: 'Bluetooth is not supported on the web',
            data: {'status': 'error'},
          ));
    }

    // TODO: ON page pop cancel stream
    // bluetoothManager.init(
    //   context: context,
    //   initiator: initiator,
    //   onDataStream: onDataStream,
    // );
    await bluetoothManager.startScan(onScanResult: (data) {
      if (onDataStream != null) {
        ScreenController().executeAction(context, onDataStream!,
            event: EnsembleEvent(
              initiator,
              data: data,
            ));
      }
      return null;
    });
  }
}

class ConnectBluetoothAction extends EnsembleAction {
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  EnsembleAction? onError;
  EnsembleAction? onDataStream;

  final String deviceId;

  ConnectBluetoothAction(
      {super.initiator,
      super.inputs,
      this.onError,
      this.onDataStream,
      required this.deviceId});

  factory ConnectBluetoothAction.from(
          {Invokable? initiator, dynamic payload}) =>
      ConnectBluetoothAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  factory ConnectBluetoothAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return ConnectBluetoothAction(
      initiator: initiator,
      inputs: Utils.getMap(payload?['inputs']),
      onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
      onDataStream:
          EnsembleAction.from(payload?['onDataStream'], initiator: initiator),
      deviceId: Utils.getString(payload?['deviceId'], fallback: 'fallback'),
    );
  }

  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    final _deviceId = scopeManager.dataContext.eval(deviceId);
    await bluetoothManager.connect(_deviceId, (data) {
      ScreenController().executeAction(context, onDataStream!,
          event: EnsembleEvent(
            initiator,
            data: data,
          ));
      return null;
    });
  }
}

class SubscribeBluetoothServiceAction extends EnsembleAction {
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  EnsembleAction? onError;
  EnsembleAction? onDataStream;

  final String characteristicsId;

  SubscribeBluetoothServiceAction(
      {super.initiator,
      super.inputs,
      this.onError,
      this.onDataStream,
      required this.characteristicsId});

  factory SubscribeBluetoothServiceAction.from(
          {Invokable? initiator, dynamic payload}) =>
      SubscribeBluetoothServiceAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  factory SubscribeBluetoothServiceAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return SubscribeBluetoothServiceAction(
      initiator: initiator,
      inputs: Utils.getMap(payload?['inputs']),
      onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
      onDataStream:
          EnsembleAction.from(payload?['onDataStream'], initiator: initiator),
      characteristicsId:
          Utils.getString(payload?['service'], fallback: 'fallback'),
    );
  }

  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    final _deviceId = scopeManager.dataContext.eval(characteristicsId);
    await bluetoothManager.subscribe(_deviceId.first['characteristicsUuid'],
        (data) {
      ScreenController().executeAction(context, onDataStream!,
          event: EnsembleEvent(
            initiator,
            data: data,
          ));
      return null;
    });
  }
}

class InvokableBluetooth extends Object with Invokable {
  InvokableBluetooth();
  static late BuildContext context;
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  @override
  Map<String, Function> getters() {
    return {
      'status': () => null,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'turnOn': () => bluetoothManager.turnOn(),
      'startScan': () => bluetoothManager.startScan(onScanResult: (data) {
            return null;
          }),
      'stopScan': () => bluetoothManager.stopScan(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}
