import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/bluetooth.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// Ensemble action that initializes Bluetooth services and streams.
class InitializeBluetoothAction extends EnsembleAction {
  /// Bluetooth manager used to run Bluetooth operations.
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  /// Action executed when the operation fails.
  EnsembleAction? onError;
  /// Action executed when stream data is emitted by a native integration.
  EnsembleAction? onDataStream;

  /// Creates a [InitializeBluetoothAction] action.
  InitializeBluetoothAction(
      {super.initiator, super.inputs, this.onError, this.onDataStream});

  /// Creates a [InitializeBluetoothAction] from a YAML or map action payload.
  factory InitializeBluetoothAction.from(
          {Invokable? initiator, dynamic payload}) =>
      InitializeBluetoothAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  /// Creates a [InitializeBluetoothAction] from a YAML or map action payload.
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

  /// Runs this action with the current Flutter context and Ensemble scope.
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

    try {
      bluetoothManager.init(
        context: context,
        initiator: initiator,
        onDataStream: onDataStream,
      );
    } catch (e) {
      if (onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(
              initiator,
              error: 'Error initializing Bluetooth: ${e.toString()}',
              data: {'status': 'error'},
            ));
      }
    }
  }
}

/// Ensemble action that starts scanning for nearby Bluetooth devices.
class StartScanBluetoothAction extends EnsembleAction {
  /// Bluetooth manager used to run Bluetooth operations.
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  /// Action executed when the operation fails.
  EnsembleAction? onError;
  /// Action executed when stream data is emitted by a native integration.
  EnsembleAction? onDataStream;

  /// Creates a [StartScanBluetoothAction] action.
  StartScanBluetoothAction(
      {super.initiator, super.inputs, this.onError, this.onDataStream});

  /// Creates a [StartScanBluetoothAction] from a YAML or map action payload.
  factory StartScanBluetoothAction.from(
          {Invokable? initiator, dynamic payload}) =>
      StartScanBluetoothAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  /// Creates a [StartScanBluetoothAction] from a YAML or map action payload.
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

  /// Runs this action with the current Flutter context and Ensemble scope.
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

    try {
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
    } catch (e) {
      if (onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(
              initiator,
              error: 'Error starting Bluetooth scan: ${e.toString()}',
              data: {'status': 'error'},
            ));
      }
    }
  }
}

/// Ensemble action that connects to a Bluetooth device.
class ConnectBluetoothAction extends EnsembleAction {
  /// Bluetooth manager used to run Bluetooth operations.
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  /// Action executed when the operation fails.
  EnsembleAction? onError;
  /// Action executed when stream data is emitted by a native integration.
  EnsembleAction? onDataStream;
  /// Action executed when Bluetooth connection state changes.
  EnsembleAction? onConnectionStream;

  /// Bluetooth device identifier targeted by the action.
  final String? deviceId;
  /// Whether Bluetooth should reconnect automatically when possible.
  final bool autoConnect;
  /// Connection timeout in seconds or milliseconds, depending on platform support.
  final int timeout;

  /// Creates a [ConnectBluetoothAction] action.
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

  /// Creates a [ConnectBluetoothAction] from a YAML or map action payload.
  factory ConnectBluetoothAction.from(
          {Invokable? initiator, dynamic payload}) =>
      ConnectBluetoothAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  /// Creates a [ConnectBluetoothAction] from a YAML or map action payload.
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

  /// Runs this action with the current Flutter context and Ensemble scope.
  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    if (deviceId == null) {
      if (onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(
              initiator,
              error: 'DeviceId is required',
              data: {'status': 'error'},
            ));
      }
      return;
    }
    final _deviceId = scopeManager.dataContext.eval(deviceId);
    try {
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
    } catch (e) {
      if (onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(
              initiator,
              error: 'Error connecting to Bluetooth device: ${e.toString()}',
              data: {'status': 'error'},
            ));
      }
    }
  }
}

/// Ensemble action that disconnects from a Bluetooth device.
class DisconnectBluetoothAction extends EnsembleAction {
  /// Bluetooth manager used to run Bluetooth operations.
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  /// Action executed when the operation fails.
  EnsembleAction? onError;
  /// Bluetooth device identifier targeted by the action.
  final String? deviceId;
  /// Creates a [DisconnectBluetoothAction] action.
  DisconnectBluetoothAction(
      {super.initiator, super.inputs, this.onError, this.deviceId});

  /// Creates a [DisconnectBluetoothAction] from a YAML or map action payload.
  factory DisconnectBluetoothAction.from(
          {Invokable? initiator, dynamic payload}) =>
      DisconnectBluetoothAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  /// Creates a [DisconnectBluetoothAction] from a YAML or map action payload.
  factory DisconnectBluetoothAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return DisconnectBluetoothAction(
      initiator: initiator,
      inputs: Utils.getMap(payload?['inputs']),
      onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
      deviceId: Utils.optionalString(payload?['deviceId']),
    );
  }

  /// Runs this action with the current Flutter context and Ensemble scope.
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

    try {
      bluetoothManager.disconnect(deviceId: _deviceId);
    } catch (e) {
      if (onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(
              initiator,
              error: 'Error disconnecting Bluetooth device: ${e.toString()}',
              data: {'status': 'error'},
            ));
      }
    }
  }
}

/// Ensemble action that subscribes to Bluetooth characteristic updates.
class SubscribeBluetoothCharacteristicsAction extends EnsembleAction {
  /// Bluetooth manager used to run Bluetooth operations.
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  /// Action executed after the operation completes successfully.
  EnsembleAction? onComplete;
  /// Action executed when the operation fails.
  EnsembleAction? onError;
  /// Action executed when stream data is emitted by a native integration.
  EnsembleAction? onDataStream;

  /// Bluetooth characteristic identifier targeted by subscription actions.
  final String? characteristicsId;

  /// Creates a [SubscribeBluetoothCharacteristicsAction] action.
  SubscribeBluetoothCharacteristicsAction(
      {super.initiator,
      super.inputs,
      this.onError,
      this.onComplete,
      this.onDataStream,
      required this.characteristicsId});

  /// Creates a [SubscribeBluetoothCharacteristicsAction] from a YAML or map action payload.
  factory SubscribeBluetoothCharacteristicsAction.from(
          {Invokable? initiator, dynamic payload}) =>
      SubscribeBluetoothCharacteristicsAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  /// Creates a [SubscribeBluetoothCharacteristicsAction] from a YAML or map action payload.
  factory SubscribeBluetoothCharacteristicsAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return SubscribeBluetoothCharacteristicsAction(
      initiator: initiator,
      inputs: Utils.getMap(payload?['inputs']),
      onComplete:
          EnsembleAction.from(payload?['onComplete'], initiator: initiator),
      onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
      onDataStream:
          EnsembleAction.from(payload?['onDataStream'], initiator: initiator),
      characteristicsId: Utils.optionalString(payload?['id']),
    );
  }

  /// Runs this action with the current Flutter context and Ensemble scope.
  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    if (characteristicsId == null) {
      if (onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(
              initiator,
              error: 'Please pass characteristics ID',
              data: {'status': 'error'},
            ));
      }
      return null;
    }

    final charId = scopeManager.dataContext.eval(characteristicsId);
    try {
      await bluetoothManager.subscribe(
        charId,
        (data) {
          if (onDataStream != null) {
            ScreenController().executeAction(context, onDataStream!,
                event: EnsembleEvent(
                  initiator,
                  data: data,
                ));
          }
          return null;
        },
        backgroundMode: true,
      );

      if (onComplete != null) {
        ScreenController().executeAction(context, onComplete!,
            event: EnsembleEvent(
              initiator,
              data: {'isListening': true},
            ));
      }
    } catch (e) {
      if (onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(
              initiator,
              error:
                  'Error subscribing to Bluetooth characteristics: ${e.toString()}',
              data: {'status': 'error', 'isListening': false},
            ));
      }
    }
  }
}

/// Ensemble action that unsubscribes from Bluetooth characteristic updates.
class UnSubscribeBluetoothCharacteristicsAction extends EnsembleAction {
  /// Bluetooth manager used to run Bluetooth operations.
  BluetoothManager bluetoothManager = GetIt.I<BluetoothManager>();

  /// Action executed after the operation completes successfully.
  EnsembleAction? onComplete;
  /// Action executed when the operation fails.
  EnsembleAction? onError;

  /// Bluetooth characteristic identifier targeted by subscription actions.
  final String? characteristicsId;

  /// Creates a [UnSubscribeBluetoothCharacteristicsAction] action.
  UnSubscribeBluetoothCharacteristicsAction(
      {super.initiator,
      super.inputs,
      this.onComplete,
      this.onError,
      required this.characteristicsId});

  /// Creates a [UnSubscribeBluetoothCharacteristicsAction] from a YAML or map action payload.
  factory UnSubscribeBluetoothCharacteristicsAction.from(
          {Invokable? initiator, dynamic payload}) =>
      UnSubscribeBluetoothCharacteristicsAction.fromYaml(
          initiator: initiator, payload: Utils.getYamlMap(payload));

  /// Creates a [UnSubscribeBluetoothCharacteristicsAction] from a YAML or map action payload.
  factory UnSubscribeBluetoothCharacteristicsAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return UnSubscribeBluetoothCharacteristicsAction(
      initiator: initiator,
      inputs: Utils.getMap(payload?['inputs']),
      onComplete:
          EnsembleAction.from(payload?['onComplete'], initiator: initiator),
      onError: EnsembleAction.from(payload?['onError'], initiator: initiator),
      characteristicsId: Utils.optionalString(payload?['id']),
    );
  }

  /// Runs this action with the current Flutter context and Ensemble scope.
  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    final charId = scopeManager.dataContext.eval(characteristicsId);
    try {
      final isListening = await bluetoothManager.unSubscribe(charId);
      if (onComplete != null) {
        ScreenController().executeAction(context, onComplete!,
            event: EnsembleEvent(
              initiator,
              data: {'isListening': !isListening},
            ));
      }
    } catch (e) {
      if (onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(
              initiator,
              error:
                  'Error unsubscribing from Bluetooth characteristics: ${e.toString()}',
              data: {'status': 'error'},
            ));
      }
    }
  }
}
