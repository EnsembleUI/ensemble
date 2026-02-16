// File: lib/widget/wifi_heatmap/wifi_heatmap.dart

import 'dart:async';

import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensembleIcon;
import 'visualization/wifi_heatmap_widget.dart';

// ignore: must_be_immutable
class WiFiHeatmap extends StatefulWidget
    with Invokable, HasController<WiFiHeatmapController, WiFiHeatmapState> {
  static const type = 'WiFiHeatmap';

  static Widget build({Key? key}) {
    return WiFiHeatmap(key: key);
  }

  WiFiHeatmap({super.key});

  final WiFiHeatmapController _controller = WiFiHeatmapController();

  @override
  WiFiHeatmapController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {
      'floorPlan': () => _controller.floorPlan,
      'gridSize': () => _controller.gridSize,
      'mode': () => _controller.mode,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'floorPlan': (v) =>
          _controller.floorPlan = Utils.getString(v, fallback: ''),
      'gridSize': (v) =>
          _controller.gridSize = Utils.optionalInt(v, min: 4, max: 40) ?? 12,
      'mode': (v) => _controller.mode = Utils.getString(v, fallback: 'setup'),

      // Icons as direct properties (not in styles)
      'modemIcon': (v) => _controller.modemIcon = _parseIcon(v),
      'routerIcon': (v) => _controller.routerIcon = _parseIcon(v),
      'locationPinIcon': (v) => _controller.locationPinIcon = _parseIcon(v),

      // Separate style maps
      'deviceStyles': (v) => _controller.deviceStyles = _parseDeviceStyles(v),
      'scanPointStyles': (v) =>
          _controller.scanPointStyles = _parseScanPointStyles(v),
      'locationPinStyles': (v) =>
          _controller.locationPinStyles = _parseLocationPinStyles(v),
      'gridStyles': (v) => _controller.gridStyles = _parseGridStyles(v),
      'heatmapStyles': (v) =>
          _controller.heatmapStyles = _parseHeatmapStyles(v),
      'pathStyles': (v) => _controller.pathStyles = _parsePathStyles(v),
      'signalStyles': (v) => _controller.signalStyles = _parseSignalStyles(v),
      'buttonStyles': (v) => _controller.buttonStyles = _parseButtonStyles(v),

      // Actions
      'onMessage': (def) => _controller.onMessage =
          ensemble.EnsembleAction.from(def, initiator: this),
      'onScanComplete': (def) => _controller.onScanComplete =
          ensemble.EnsembleAction.from(def, initiator: this),
      'getSignalStrength': (def) => _controller.getSignalStrength =
          ensemble.EnsembleAction.from(def, initiator: this),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'startScanning': () => _controller._startScanning?.call(),
      'reset': () => _controller._reset?.call(),
    };
  }

  Icon? _parseIcon(dynamic v) {
    if (v == null) return null;
    final iconModel = Utils.getIcon(v);
    if (iconModel == null) return null;
    return ensembleIcon.Icon.fromModel(iconModel);
  }

  DeviceStyles _parseDeviceStyles(dynamic value) {
    if (value is! Map) return const DeviceStyles();
    final map = value;
    return DeviceStyles(
      markerSize: Utils.optionalDouble(map['markerSize']) ?? 36.0,
      iconSize: Utils.optionalDouble(map['iconSize']) ?? 22.0,
      borderWidth: Utils.optionalDouble(map['borderWidth']) ?? 2.8,
      borderColor: Utils.getColor(map['borderColor']) ?? Colors.white,
      modemColor: Utils.getColor(map['modemColor']) ?? Colors.red,
      modemIconColor: Utils.getColor(map['modemIconColor']) ?? Colors.white,
      routerColor: Utils.getColor(map['routerColor']) ?? Colors.blue,
      routerIconColor: Utils.getColor(map['routerIconColor']) ?? Colors.white,
    );
  }

  ScanPointStyles _parseScanPointStyles(dynamic value) {
    if (value is! Map) return const ScanPointStyles();
    final map = value;
    return ScanPointStyles(
      dotSizeFactor: Utils.optionalDouble(map['dotSizeFactor']) ?? 0.4,
      color: Utils.getColor(map['color']) ?? Colors.blueAccent,
      borderColor:
          Utils.getColor(map['borderColor']) ?? const Color(0xB3FFFFFF),
      borderWidth: Utils.optionalDouble(map['borderWidth']) ?? 1.8,
    );
  }

  LocationPinStyles _parseLocationPinStyles(dynamic value) {
    if (value is! Map) return const LocationPinStyles();
    final map = value;
    return LocationPinStyles(
      size: Utils.optionalDouble(map['size']) ?? 44.0,
      color: Utils.getColor(map['color']) ?? Colors.red,
    );
  }

  GridStyles _parseGridStyles(dynamic value) {
    if (value is! Map) return const GridStyles();
    final map = value;
    return GridStyles(
      lineWidth: Utils.optionalDouble(map['lineWidth']) ?? 0.6,
      alpha: Utils.optionalInt(map['alpha'], min: 0, max: 255) ?? 60,
      lineColor: Utils.getColor(map['lineColor']) ?? Colors.black,
    );
  }

  HeatmapStyles _parseHeatmapStyles(dynamic value) {
    if (value is! Map) return const HeatmapStyles();
    final map = value;
    return HeatmapStyles(
      fillAlpha: Utils.optionalInt(map['fillAlpha'], min: 0, max: 255) ?? 123,
    );
  }

  PathStyles _parsePathStyles(dynamic value) {
    if (value is! Map) return const PathStyles();
    final map = value;
    return PathStyles(
      color: Utils.getColor(map['color']) ?? const Color(0xFF1976D2),
      width: Utils.optionalDouble(map['width']) ?? 2.8,
    );
  }

  SignalStyles _parseSignalStyles(dynamic value) {
    if (value is! Map) return const SignalStyles();
    final map = value;
    return SignalStyles(
      excellentColor:
          Utils.getColor(map['excellentColor']) ?? const Color(0xFF388E3C),
      veryGoodColor:
          Utils.getColor(map['veryGoodColor']) ?? const Color(0xFF66BB6A),
      goodColor: Utils.getColor(map['goodColor']) ?? const Color(0xFFAFB42B),
      fairColor: Utils.getColor(map['fairColor']) ?? const Color(0xFFF57C00),
      poorColor: Utils.getColor(map['poorColor']) ?? const Color(0xFFE64A19),
      badColor: Utils.getColor(map['badColor']) ?? const Color(0xFFC62828),
    );
  }

  ButtonStyles _parseButtonStyles(dynamic value) {
    if (value is! Map) return const ButtonStyles();
    final map = value;
    return ButtonStyles(
      startScanColor:
          Utils.getColor(map['startScanColor']) ?? const Color(0xFF388E3C),
      addCheckpointColor:
          Utils.getColor(map['addCheckpointColor']) ?? const Color(0xFF1976D2),
    );
  }

  @override
  State<StatefulWidget> createState() => WiFiHeatmapState();
}

class WiFiHeatmapController extends BoxController {
  String floorPlan = '';
  int gridSize = 12;
  String mode = 'setup';

  // Icons as direct properties (not in styles)
  Icon? modemIcon;
  Icon? routerIcon;
  Icon? locationPinIcon;

  // Separate style maps
  DeviceStyles deviceStyles = const DeviceStyles();
  ScanPointStyles scanPointStyles = const ScanPointStyles();
  LocationPinStyles locationPinStyles = const LocationPinStyles();
  GridStyles gridStyles = const GridStyles();
  HeatmapStyles heatmapStyles = const HeatmapStyles();
  PathStyles pathStyles = const PathStyles();
  SignalStyles signalStyles = const SignalStyles();
  ButtonStyles buttonStyles = const ButtonStyles();

  // Actions
  ensemble.EnsembleAction? onMessage;
  ensemble.EnsembleAction? onScanComplete;
  ensemble.EnsembleAction? getSignalStrength;

  VoidCallback? _startScanning;
  VoidCallback? _reset;

  void showMessage(String msg, BuildContext context) {
    print('WiFiHeatmap showMessage: $msg');

    if (onMessage != null) {
      ScreenController().executeAction(
        context,
        onMessage!,
        event: EnsembleEvent(null, data: {'message': msg}),
      );
    } else {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    }
  }
}

class WiFiHeatmapState extends EWidgetState<WiFiHeatmap> {
  final _heatmapKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    widget.controller._startScanning = () {
      if (widget.controller.mode != 'scanning' && mounted) {
        setState(() {
          widget.controller.mode = 'scanning';
        });
      }
    };

    widget.controller._reset = () {
      if (mounted) {
        setState(() {
          widget.controller.mode = 'setup';
        });
      }
    };
  }

  @override
  Widget buildWidget(BuildContext context) {
    return BoxWrapper(
      boxController: widget.controller,
      widget: WiFiHeatmapWidget(
        key: _heatmapKey,
        floorPlan: widget.controller.floorPlan,
        gridSize: widget.controller.gridSize,
        deviceStyles: widget.controller.deviceStyles,
        scanPointStyles: widget.controller.scanPointStyles,
        locationPinStyles: widget.controller.locationPinStyles,
        gridStyles: widget.controller.gridStyles,
        heatmapStyles: widget.controller.heatmapStyles,
        pathStyles: widget.controller.pathStyles,
        signalStyles: widget.controller.signalStyles,
        buttonStyles: widget.controller.buttonStyles,
        modemIcon: widget.controller.modemIcon,
        routerIcon: widget.controller.routerIcon,
        locationPinIcon: widget.controller.locationPinIcon,
        getSignalStrength: _getSignalStrength,
        onShowMessage: (msg) => widget.controller.showMessage(msg, context),
      ),
    );
  }

  Future<SignalResult> _getSignalStrength() async {
    // Fallback random signal generation
    await Future.delayed(const Duration(milliseconds: 600));
    const values = [-45, -52, -58, -64, -72, -79, -88, -94];
    final rssi = values[DateTime.now().millisecond % values.length];
    final color = widget.controller.signalStyles.getSignalColor(rssi);
    return SignalResult(rssi, color);
  }
}
