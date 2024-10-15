// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ensemble/action/bluetooth_action.dart';
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
  void init({
    required BuildContext context,
    EnsembleAction? onDataStream,
    Invokable? initiator,
  }) {
    try {
      _adapterStateStateSubscription =
          FlutterBluePlus.adapterState.listen((state) async {
        _adapterState = state;

        // if (_adapterState.name != 'on' && Platform.isAndroid) {
        //   await FlutterBluePlus.turnOn();
        // }

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
                    'advName': e.advertisementData.advName,
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
  Future<void> connect(
      String deviceId, ServiceFoundCallback onServiceFound) async {
    final device = _scanResults
        .firstWhereOrNull((element) => element.device.remoteId.str == deviceId)
        ?.device;

    await device?.connect();

    device?.connectionState.listen((event) async {
      if (event == BluetoothConnectionState.connected) {
        _bluetoothServices = await device.discoverServices();
        final data = _bluetoothServices
            .map((e) => {
                  'serviceId': e.serviceUuid.str,
                  'characteristics': e.characteristics
                      .map((e) => {
                            'id': e.characteristicUuid.str,
                          })
                      .toList(),
                })
            .toList();
        onServiceFound.call(data); // services.first
      }
    });
  }

  @override
  Future<void> subscribe(
      String characteristicId, DataReceivedCallback onDataReceive) async {
    for (var service in _bluetoothServices) {
      final c = service.characteristics.firstWhereOrNull(
          (element) => element.characteristicUuid.str == characteristicId);
      if (c != null) {
        await c.setNotifyValue(c.isNotifying == false);
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
        await c.setNotifyValue(c.isNotifying == false);

        break;
      }
    }
  }

  @override
  InvokableBluetooth getInvokableBluetooth() {
    // TODO: implement getInvokableBluetooth
    throw UnimplementedError();
  }
}
