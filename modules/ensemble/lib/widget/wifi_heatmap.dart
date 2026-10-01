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
      'signalValues': () => _controller.signalValues,
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

      'modemIcon': (v) => _controller.modemIcon = _parseIcon(v),
      'routerIcon': (v) => _controller.routerIcon = _parseIcon(v),
      'locationPinIcon': (v) => _controller.locationPinIcon = _parseIcon(v),

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

      'signalValues': (v) {
        print(
            'WiFiHeatmap setter signalValues called with: $v ${v.runtimeType}');
        _controller.signalValues = _parseSignalValues(v);
        return _controller.signalValues;
      },

      // Actions
      'onMessage': (def) => _controller.onMessage =
          ensemble.EnsembleAction.from(def, initiator: this),
      'onScanComplete': (def) => _controller.onScanComplete =
          ensemble.EnsembleAction.from(def, initiator: this),
      'getSignalStrength': (def) => _controller.getSignalStrength =
          ensemble.EnsembleAction.from(def, initiator: this),
      'onFirstCheckpoint': (def) => _controller.onFirstCheckpoint =
          ensemble.EnsembleAction.from(def, initiator: this),
      'onAllGridsFilled': (def) => _controller.onAllGridsFilled =
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

  List<Map<String, dynamic>> _parseSignalValues(dynamic value) {
    if (value == null) return [];

    // If it's already a list
    if (value is List) {
      return value.map((item) {
        if (item is Map) {
          // Ensure we have both timestamp and dbm
          final timestamp = item['timestamp'];
          final dbm = item['dbm'] ?? item['value'];

          if (timestamp != null && dbm != null) {
            return {
              'timestamp': timestamp is int
                  ? timestamp
                  : int.tryParse(timestamp.toString()) ??
                      DateTime.now().millisecondsSinceEpoch,
              'dbm': dbm is int ? dbm : int.tryParse(dbm.toString()) ?? -100,
            };
          }
        }
        // If item is just a number, treat it as dbm with current timestamp
        if (item is int) {
          return {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'dbm': item,
          };
        }
        return {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'dbm': -100,
        };
      }).toList();
    }

    return [];
  }

  DeviceStyles _parseDeviceStyles(dynamic value) {
    if (value is! Map) return const DeviceStyles();
    final map = value;
    return DeviceStyles(
      markerSize: Utils.optionalDouble(map['markerSize']),
      iconSize: Utils.optionalDouble(map['iconSize']),
      borderWidth: Utils.optionalDouble(map['borderWidth']),
      borderColor: Utils.getColor(map['borderColor']),
      modemColor: Utils.getColor(map['modemColor']),
      modemIconColor: Utils.getColor(map['modemIconColor']),
      routerColor: Utils.getColor(map['routerColor']),
      routerIconColor: Utils.getColor(map['routerIconColor']),
    );
  }

  ScanPointStyles _parseScanPointStyles(dynamic value) {
    if (value is! Map) return const ScanPointStyles();
    final map = value;
    return ScanPointStyles(
      dotSizeFactor: Utils.optionalDouble(map['dotSizeFactor']),
      color: Utils.getColor(map['color']),
      borderColor: Utils.getColor(map['borderColor']),
      borderWidth: Utils.optionalDouble(map['borderWidth']),
    );
  }

  LocationPinStyles _parseLocationPinStyles(dynamic value) {
    if (value is! Map) return const LocationPinStyles();
    final map = value;
    return LocationPinStyles(
      size: Utils.optionalDouble(map['size']),
      color: Utils.getColor(map['color']),
    );
  }

  GridStyles _parseGridStyles(dynamic value) {
    if (value is! Map) return const GridStyles();
    final map = value;
    return GridStyles(
      lineWidth: Utils.optionalDouble(map['lineWidth']),
      alpha: Utils.optionalInt(map['alpha'], min: 0, max: 255),
      lineColor: Utils.getColor(map['lineColor']),
    );
  }

  HeatmapStyles _parseHeatmapStyles(dynamic value) {
    if (value is! Map) return const HeatmapStyles();
    final map = value;
    return HeatmapStyles(
      fillAlpha: Utils.optionalInt(map['fillAlpha'], min: 0, max: 255),
    );
  }

  PathStyles _parsePathStyles(dynamic value) {
    if (value is! Map) return const PathStyles();
    final map = value;
    return PathStyles(
      color: Utils.getColor(map['color']),
      width: Utils.optionalDouble(map['width']),
    );
  }

  SignalStyles _parseSignalStyles(dynamic value) {
    if (value is! Map) return const SignalStyles();
    final map = value;
    return SignalStyles(
      excellentColor: Utils.getColor(map['excellentColor']),
      veryGoodColor: Utils.getColor(map['veryGoodColor']),
      goodColor: Utils.getColor(map['goodColor']),
      fairColor: Utils.getColor(map['fairColor']),
      poorColor: Utils.getColor(map['poorColor']),
      badColor: Utils.getColor(map['badColor']),
    );
  }

  ButtonStyles _parseButtonStyles(dynamic value) {
    if (value is! Map) return const ButtonStyles();
    final map = value;
    return ButtonStyles(
      startScanColor: Utils.getColor(map['startScanColor']),
      addCheckpointColor: Utils.getColor(map['addCheckpointColor']),
    );
  }

  @override
  State<StatefulWidget> createState() => WiFiHeatmapState();
}

class WiFiHeatmapController extends BoxController {
  String floorPlan = '';
  int gridSize = 12;
  String mode = 'setup';
  // Icons as direct
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
  // External signal values (timestamp+dBm objects passed from outside)
  List<Map<String, dynamic>> signalValues = [];
  // Actions
  ensemble.EnsembleAction? onMessage;
  ensemble.EnsembleAction? onScanComplete;
  ensemble.EnsembleAction? getSignalStrength;
  ensemble.EnsembleAction? onFirstCheckpoint;
  ensemble.EnsembleAction? onAllGridsFilled;

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

  void triggerFirstCheckpoint(BuildContext context) {
    print('WiFiHeatmap triggerFirstCheckpoint');
    if (onFirstCheckpoint != null) {
      ScreenController().executeAction(
        context,
        onFirstCheckpoint!,
        event: EnsembleEvent(null),
      );
    }
  }

  void triggerAllGridsFilled(BuildContext context) {
    print('WiFiHeatmap triggerAllGridsFilled');
    if (onAllGridsFilled != null) {
      ScreenController().executeAction(
        context,
        onAllGridsFilled!,
        event: EnsembleEvent(null),
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
        signalValues: widget.controller.signalValues,
        getSignalStrength: _getSignalStrength,
        onShowMessage: (msg) => widget.controller.showMessage(msg, context),
        onFirstCheckpoint: () =>
            widget.controller.triggerFirstCheckpoint(context),
        onAllGridsFilled: () =>
            widget.controller.triggerAllGridsFilled(context),
      ),
    );
  }

  Future<SignalResult> _getSignalStrength() async {
    // Fallback random signal generation (for backward compatibility)
    await Future.delayed(const Duration(milliseconds: 600));
    const values = [-45, -52, -58, -64, -72, -79, -88, -94];
    final rssi = values[DateTime.now().millisecond % values.length];
    final color = widget.controller.signalStyles.getSignalColor(rssi);
    return SignalResult(rssi, color);
  }
}
