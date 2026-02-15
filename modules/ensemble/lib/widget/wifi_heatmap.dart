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
          _controller.gridSize = Utils.optionalInt(v, min: 4, max: 40),
      'mode': (v) => _controller.mode = Utils.getString(v, fallback: 'setup'),
      'theme': (v) => _controller.theme = _parseCustomTheme(v),
      'onMessage': (def) => _controller.onMessage =
          ensemble.EnsembleAction.from(def, initiator: this),
      'onScanComplete': (def) => _controller.onScanComplete =
          ensemble.EnsembleAction.from(def, initiator: this),
      'getSignalStrength': (v) => _controller.customGetSignalStrength = v,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'startScanning': () => _controller._startScanning?.call(),
      'reset': () => _controller._reset?.call(),
    };
  }

  WiFiHeatmapTheme? _parseCustomTheme(dynamic value) {
    if (value is! Map) return null;

    final map = value;

    Icon? parseIcon(dynamic v) {
      if (v == null) return null;

      final iconModel = Utils.getIcon(v);
      if (iconModel == null) return null;
      return ensembleIcon.Icon.fromModel(iconModel);
    }

    return WiFiHeatmapTheme(
      // Device marker properties
      deviceMarkerSize: Utils.optionalDouble(map['deviceMarkerSize']),
      deviceIconSize: Utils.optionalDouble(map['deviceIconSize']),
      deviceBorderWidth: Utils.optionalDouble(map['deviceBorderWidth']),
      deviceBorderColor: Utils.getColor(map['deviceBorderColor']),

      // Modem properties
      modemColor: Utils.getColor(map['modemColor']),
      modemIconColor: Utils.getColor(map['modemIconColor']),
      modemIcon: parseIcon(map['modemIcon']),

      // Router properties
      routerColor: Utils.getColor(map['routerColor']),
      routerIconColor: Utils.getColor(map['routerIconColor']),
      routerIcon: parseIcon(map['routerIcon']),

      // Scan point properties
      scanPointDotSizeFactor:
          Utils.optionalDouble(map['scanPointDotSizeFactor']),
      scanPointColor: Utils.getColor(map['scanPointColor']),
      scanPointBorderColor: Utils.getColor(map['scanPointBorderColor']),
      scanPointBorderWidth: Utils.optionalDouble(map['scanPointBorderWidth']),

      // Location pin properties
      locationPinSize: Utils.optionalDouble(map['locationPinSize']),
      locationPinColor: Utils.getColor(map['locationPinColor']),
      locationPinIcon: parseIcon(map['locationPinIcon']),

      // Grid properties
      gridLineWidth: Utils.optionalDouble(map['gridLineWidth']),
      gridAlpha: Utils.optionalInt(map['gridAlpha'], min: 0, max: 255),
      gridLineColor: Utils.getColor(map['gridLineColor']),

      // Heatmap properties
      heatmapFillAlpha:
          Utils.optionalInt(map['heatmapFillAlpha'], min: 0, max: 255),

      // Path properties
      pathColor: Utils.getColor(map['pathColor']),
      pathWidth: Utils.optionalDouble(map['pathWidth']),

      // Grid size properties
      defaultGridSize:
          Utils.optionalInt(map['defaultGridSize'], min: 4, max: 32),
      targetCellSize: Utils.optionalDouble(map['targetCellSize']),

      // Signal color properties
      excellentSignalColor: Utils.getColor(map['excellentSignalColor']),
      veryGoodSignalColor: Utils.getColor(map['veryGoodSignalColor']),
      goodSignalColor: Utils.getColor(map['goodSignalColor']),
      fairSignalColor: Utils.getColor(map['fairSignalColor']),
      poorSignalColor: Utils.getColor(map['poorSignalColor']),
      badSignalColor: Utils.getColor(map['badSignalColor']),

      // Button color properties
      startScanButtonColor: Utils.getColor(map['startScanButtonColor']),
      addCheckpointButtonColor: Utils.getColor(map['addCheckpointButtonColor']),
    );
  }

  @override
  State<StatefulWidget> createState() => WiFiHeatmapState();
}

class WiFiHeatmapController extends BoxController {
  String floorPlan = '';
  int? gridSize;
  String mode = 'setup';

  WiFiHeatmapTheme? theme;

  ensemble.EnsembleAction? onMessage;
  ensemble.EnsembleAction? onScanComplete;

  dynamic customGetSignalStrength;

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
        theme: widget.controller.theme ?? const WiFiHeatmapTheme(),
        getSignalStrength: _getSignalStrength,
        onShowMessage: (msg) => widget.controller.showMessage(msg, context),
      ),
    );
  }

  Future<SignalResult> _getSignalStrength() async {
    if (widget.controller.customGetSignalStrength != null) {
      try {
        final result = await widget.controller.customGetSignalStrength();
        if (result is Map && result['dBm'] != null) {
          final dBm = Utils.getInt(result['dBm'], fallback: -70);
          final colorStr = result['color'];

          Color color;
          if (colorStr != null) {
            color = Utils.getColor(colorStr) ??
                widget.controller.theme?.getSignalColor(dBm) ??
                const WiFiHeatmapTheme().getSignalColor(dBm);
          } else {
            color = widget.controller.theme?.getSignalColor(dBm) ??
                const WiFiHeatmapTheme().getSignalColor(dBm);
          }

          return SignalResult(dBm, color);
        }
      } catch (e) {
        print('Custom getSignalStrength failed: $e');
      }
    }

    // Fallback random signal generation
    await Future.delayed(const Duration(milliseconds: 600));
    const values = [-45, -52, -58, -64, -72, -79, -88, -94];
    final rssi = values[DateTime.now().millisecond % values.length];
    final color = widget.controller.theme?.getSignalColor(rssi) ??
        const WiFiHeatmapTheme().getSignalColor(rssi);
    return SignalResult(rssi, color);
  }
}
