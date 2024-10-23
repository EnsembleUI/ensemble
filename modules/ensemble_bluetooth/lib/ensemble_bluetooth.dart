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

  late StreamSubscription<BluetoothAdapterState> _adapterStateStateSubscription;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;

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
      _adapterStateStateSubscription =
          FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;

        if (onDataStream != null) {
          ScreenController().executeAction(context, onDataStream,
              event: EnsembleEvent(
                initiator,
                data: _adapterState.name,
              ));
        }
      });
    } on Exception catch (error) {
      print(error);
    }
  }

  @override
  Future<void> turnOn() async {
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }
  }

  @override
  void dispose() {
    _adapterStateStateSubscription.cancel();
    _scanResultsSubscription.cancel();
  }

  @override
  Future startScan({required ScanResultCallback onScanResult}) async {
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
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
                      'serviceIds': e.advertisementData.serviceUuids,
                      'serviceData': e.advertisementData.serviceData,
                    },
                  })
              .toList(),
        );
      }, onError: (e) {});
    } catch (e) {
      print(e);
    }
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  @override
  Future<void> subscribe(
      String characteristicId, DataReceivedCallback onDataReceive) async {
    for (var service in _bluetoothServices) {
      final c = service.characteristics.firstWhereOrNull(
          (element) => element.characteristicUuid.str == characteristicId);
      if (c != null) {
        await c.setNotifyValue(true);

        c.onValueReceived.listen((value) {
          final data = utf8.decode(value);
          onDataReceive.call(data);
        });
        break;
      }
    }
  }

  @override
  Future<void> unSubscribe(String characteristicId) async {
    for (var service in _bluetoothServices) {
      final c = service.characteristics.firstWhereOrNull(
          (element) => element.characteristicUuid.str == characteristicId);
      if (c != null) {
        await c.setNotifyValue(false);
        break;
      }
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
    final device = _scanResults
        .firstWhereOrNull((element) => element.device.remoteId.str == deviceId)
        ?.device;

    await device?.connect(
      autoConnect: autoConnect,
      timeout: Duration(seconds: timeout),
      mtu: autoConnect ? null : 512,
    );

    device?.connectionState.listen((event) async {
      connectionState.call(event.name);

      if (event == BluetoothConnectionState.connected) {
        _bluetoothServices = await device.discoverServices();
        final data = _bluetoothServices
            .map((e) => {
                  'serviceId': e.serviceUuid.str,
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
      }
    });
  }

  @override
  void disconnect({required String deviceId}) {
    final device = _scanResults
        .firstWhereOrNull((element) => element.device.remoteId.str == deviceId)
        ?.device;

    device?.disconnect();
  }
}
