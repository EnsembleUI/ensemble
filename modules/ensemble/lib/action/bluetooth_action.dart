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

    bluetoothManager.init(
      context: context,
      initiator: initiator,
      onDataStream: onDataStream,
    );
  }
}

class StartScanBluetoothAction extends EnsembleAction {
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  EnsembleAction? onError;
  EnsembleAction? onDataStream;

  StartScanBluetoothAction(
      {super.initiator, super.inputs, this.onError, this.onDataStream});

  factory StartScanBluetoothAction.from(
          {Invokable? initiator, dynamic payload}) =>
      StartScanBluetoothAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  factory StartScanBluetoothAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return StartScanBluetoothAction(
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
  EnsembleAction? onConnectionStream;

  final String? deviceId;
  final bool autoConnect;
  final int timeout;

  ConnectBluetoothAction({
    super.initiator,
    super.inputs,
    this.onError,
    this.onDataStream,
    this.onConnectionStream,
    required this.deviceId,
    required this.autoConnect,
    required this.timeout,
  });

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
      onConnectionStream: EnsembleAction.from(payload?['onConnectionStream'],
          initiator: initiator),
      deviceId: Utils.optionalString(payload?['deviceId']),
      autoConnect: Utils.getBool(payload?['autoConnect'], fallback: false),
      timeout: Utils.getInt(payload?['timeout'], fallback: 35),
    );
  }

  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    if (deviceId == null) {
      if (onError != null) {
        ScreenController().executeAction(context, onDataStream!,
            event: EnsembleEvent(
              initiator,
              error: 'DeviceId is required',
            ));
      }
      return;
    }
    final _deviceId = scopeManager.dataContext.eval(deviceId);
    await bluetoothManager.connect(
      deviceId: _deviceId,
      autoConnect: autoConnect,
      timeout: timeout,
      onServiceFound: (data) {
        if (onDataStream != null) {
          ScreenController().executeAction(context, onDataStream!,
              event: EnsembleEvent(
                initiator,
                data: data,
              ));
        }
        return null;
      },
      connectionState: (data) {
        if (onConnectionStream != null) {
          ScreenController().executeAction(context, onConnectionStream!,
              event: EnsembleEvent(
                initiator,
                data: {'status': data},
              ));
        }
        return null;
      },
    );
  }
}

class DisconnectBluetoothAction extends EnsembleAction {
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  EnsembleAction? onError;
  final String? deviceId;
  DisconnectBluetoothAction(
      {super.initiator, super.inputs, this.onError, this.deviceId});

  factory DisconnectBluetoothAction.from(
          {Invokable? initiator, dynamic payload}) =>
      DisconnectBluetoothAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  factory DisconnectBluetoothAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return DisconnectBluetoothAction(
      initiator: initiator,
      inputs: Utils.getMap(payload?['inputs']),
      onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
      deviceId: Utils.optionalString(payload?['deviceId']),
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
    final _deviceId = scopeManager.dataContext.eval(deviceId);

    bluetoothManager.disconnect(deviceId: _deviceId);
  }
}

class SubscribeBluetoothCharacteristicsAction extends EnsembleAction {
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  EnsembleAction? onError;
  EnsembleAction? onDataStream;

  final String? characteristicsId;

  SubscribeBluetoothCharacteristicsAction(
      {super.initiator,
      super.inputs,
      this.onError,
      this.onDataStream,
      required this.characteristicsId});

  factory SubscribeBluetoothCharacteristicsAction.from(
          {Invokable? initiator, dynamic payload}) =>
      SubscribeBluetoothCharacteristicsAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  factory SubscribeBluetoothCharacteristicsAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return SubscribeBluetoothCharacteristicsAction(
      initiator: initiator,
      inputs: Utils.getMap(payload?['inputs']),
      onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
      onDataStream:
          EnsembleAction.from(payload?['onDataStream'], initiator: initiator),
      characteristicsId: Utils.optionalString(payload?['id']),
    );
  }

  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    if (characteristicsId == null) {
      if (onError != null) {
        ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(
              initiator,
              error: 'Please pass characteristics ID',
            ));
      }
      return null;
    }

    final charId = scopeManager.dataContext.eval(characteristicsId);
    await bluetoothManager.subscribe(charId, (data) {
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

class UnSubscribeBluetoothCharacteristicsAction extends EnsembleAction {
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  EnsembleAction? onError;

  final String characteristicsId;

  UnSubscribeBluetoothCharacteristicsAction(
      {super.initiator,
      super.inputs,
      this.onError,
      required this.characteristicsId});

  factory UnSubscribeBluetoothCharacteristicsAction.from(
          {Invokable? initiator, dynamic payload}) =>
      UnSubscribeBluetoothCharacteristicsAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  factory UnSubscribeBluetoothCharacteristicsAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return UnSubscribeBluetoothCharacteristicsAction(
      initiator: initiator,
      inputs: Utils.getMap(payload?['inputs']),
      onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
      characteristicsId: Utils.getString(payload?['id'], fallback: 'fallback'),
    );
  }

  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    final charId = scopeManager.dataContext.eval(characteristicsId);
    await bluetoothManager.unSubscribe(charId);
  }
}
