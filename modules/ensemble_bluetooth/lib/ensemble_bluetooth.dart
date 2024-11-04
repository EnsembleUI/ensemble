// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/stub/bluetooth.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:collection/collection.dart';

class BluetoothManagerImpl extends BluetoothManager {
  static BluetoothManagerImpl? _instance;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  List<ScanResult> _scanResults = [];
  List<BluetoothService> _bluetoothServices = [];

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  final Map<String, StreamSubscription<BluetoothConnectionState>>
      _connectionStateSubscriptions = {};
  final Map<String, StreamSubscription> _characteristicValueSubscriptions = {};

  factory BluetoothManagerImpl() {
    _instance ??= BluetoothManagerImpl._internal();
    return _instance!;
  }

  BluetoothManagerImpl._internal();

  @override
  Future<void> init({
    required BuildContext context,
    EnsembleAction? onDataStream,
    Invokable? initiator,
  }) async {
    try {
      if (_adapterState.name != 'on' && Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
      _adapterStateSubscription?.cancel();
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;
        if (onDataStream != null) {
          ScreenController().executeAction(context, onDataStream,
              event: EnsembleEvent(
                initiator,
                data: _adapterState.name,
              ));
        }
      }, onError: (error) {
        throw Exception('Error in adapter state stream: $error');
      });
    } catch (error) {
      throw Exception('Failed to initialize Bluetooth: $error');
    }
  }

  @override
  Future<void> turnOn() async {
    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (error) {
        throw Exception('Failed to turn on Bluetooth: $error');
      }
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    for (var subscription in _connectionStateSubscriptions.values) {
      subscription.cancel();
    }
    for (var subscription in _characteristicValueSubscriptions.values) {
      subscription.cancel();
    }
    _connectionStateSubscriptions.clear();
    _characteristicValueSubscriptions.clear();
  }

  @override
  Future startScan({required ScanResultCallback onScanResult}) async {
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
      _scanResultsSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        onScanResult.call(
          results
              .map((e) => {
                    'deviceId': e.device.remoteId.str,
                    'connectable': e.advertisementData.connectable,
                    'advData': {
                      'name': e.advertisementData.advName,
                      'txPowerLevel': e.advertisementData.txPowerLevel,
                      'appearance': e.advertisementData.appearance,
                      'serviceIds': e.advertisementData.serviceUuids
                          .map((e) => e.str)
                          .toList(),
                    },
                  })
              .toList(),
        );
      }, onError: (e) {
        throw Exception('Error during Bluetooth scan: $e');
      });
    } catch (e) {
      throw Exception('Failed to start Bluetooth scan: $e');
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;
    } catch (e) {
      throw Exception('Failed to stop Bluetooth scan: $e');
    }
  }

  @override
  Future<void> subscribe(
      String characteristicId, DataReceivedCallback onDataReceive) async {
    try {
      for (var service in _bluetoothServices) {
        final c = service.characteristics.firstWhereOrNull(
            (element) => element.characteristicUuid.str == characteristicId);
        if (c != null) {
          await c.setNotifyValue(true);
          _characteristicValueSubscriptions[characteristicId]?.cancel();
          _characteristicValueSubscriptions[characteristicId] =
              c.onValueReceived.listen((value) {
            final data = utf8.decode(value);
            onDataReceive.call(data);
          }, onError: (error) {
            throw Exception('Error in characteristic value stream: $error');
          });
          return;
        }
      }
      throw Exception('Characteristic not found: $characteristicId');
    } catch (e) {
      throw Exception('Failed to subscribe to characteristic: $e');
    }
  }

  @override
  Future<bool> unSubscribe(String characteristicId) async {
    try {
      for (var service in _bluetoothServices) {
        final c = service.characteristics.firstWhereOrNull(
            (element) => element.characteristicUuid.str == characteristicId);
        if (c != null) {
          await c.setNotifyValue(false);
          _characteristicValueSubscriptions[characteristicId]?.cancel();
          _characteristicValueSubscriptions.remove(characteristicId);
          return true;
        }
      }
      throw Exception('Characteristic not found: $characteristicId');
    } catch (e) {
      throw Exception('Failed to unsubscribe from characteristic: $e');
    }
  }

  @override
  Future<void> connect({
    required String deviceId,
    required ServiceFoundCallback onServiceFound,
    required DataReceivedCallback connectionState,
    required bool autoConnect,
    required int timeout,
  }) async {
    try {
      final device = BluetoothDevice.fromId(deviceId);

      await device.connect(
        autoConnect: autoConnect,
        timeout: Duration(seconds: timeout),
        mtu: autoConnect ? null : 512,
      );

      _connectionStateSubscriptions[deviceId]?.cancel();
      _connectionStateSubscriptions[deviceId] =
          device.connectionState.listen((event) async {
        if (event == BluetoothConnectionState.connected) {
          _bluetoothServices = await device.discoverServices();
          final data = _bluetoothServices
              .map((e) => {
                    'serviceId': e.serviceUuid.str,
                    'connectionStatus': event.name,
                    'characteristics': e.characteristics
                        .map((e) => {
                              'id': e.characteristicUuid.str,
                              'isReadable': e.properties.read,
                              'isWritable': e.properties.write,
                              'isSubscribable':
                                  e.properties.notify || e.properties.indicate,
                            })
                        .toList(),
                  })
              .toList();
          onServiceFound.call(data);
        } else if (event == BluetoothConnectionState.disconnected) {
          _connectionStateSubscriptions[deviceId]?.cancel();
          _connectionStateSubscriptions.remove(deviceId);
        }
        connectionState.call(event.name);
      }, onError: (error) {
        throw Exception('Error in connection state stream: $error');
      });
    } catch (e) {
      throw Exception('Failed to connect to device: $e');
    }
  }

  @override
  Future<void> disconnect({required String deviceId}) async {
    try {
      final device = BluetoothDevice.fromId(deviceId);
      await device.disconnect();
      _connectionStateSubscriptions[deviceId]?.cancel();
      _connectionStateSubscriptions.remove(deviceId);
    } catch (e) {
      throw Exception('Failed to disconnect from device: $e');
    }
  }
}
