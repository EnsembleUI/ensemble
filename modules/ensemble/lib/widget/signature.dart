import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:signature/signature.dart';
import 'dart:convert'; // For base64 encoding and decoding
import 'package:flutter_svg/svg.dart';

class EnsembleSignature extends EnsembleWidget<EnsembleSignatureController> {
  static const type = 'Signature';

  const EnsembleSignature._(super.controller, {super.key});

  factory EnsembleSignature.build(dynamic controller) => EnsembleSignature._(
      controller is EnsembleSignatureController
          ? controller
          : EnsembleSignatureController());

  @override
  State<StatefulWidget> createState() => EnsembleSignatureState();
}

class EnsembleSignatureController extends EnsembleBoxController {
  Color penColor = Colors.black;
  double penStrokeWidth = 3.0;
  Color? backgroundColor = Colors.grey[200];
  SignatureController signatureController;
  String? value;
  bool disabled = false;
  StrokeCap strokeCap = StrokeCap.butt;
  StrokeJoin strokeJoin = StrokeJoin.miter;
  Color? exportBackgroundColor;
  Color? exportPenColor;
  Uint8List? _cachedSignatureBytes;
  SvgPicture? _cachedSignatureSVG;
  ui.Image? _cachedSignatureJPG;

  EnsembleSignatureController() : signatureController = SignatureController(
        penStrokeWidth: 3.0,
        penColor: Colors.black,
        exportBackgroundColor: Colors.grey[200],
      ) {
    signatureController.onDrawEnd = () {
      value = _convertPointsToBase64(signatureController.points);
      if (signatureController.isNotEmpty) {
          signatureController.toPngBytes().then((bytes) {
          _cachedSignatureBytes = bytes;
        });
        _cachedSignatureSVG = signatureController.toSVG();
        signatureController.toImage().then((image) {
          _cachedSignatureJPG = image;
        });
      }
      
    };
  }

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'penColor': (value) {
        penColor = Utils.getColor(value) ?? penColor;
        _updateSignatureController();
      },
      'penStrokeWidth': (value) {
        penStrokeWidth = Utils.optionalDouble(value) ?? penStrokeWidth;
        _updateSignatureController();
      },
      'backgroundColor': (value) {
        backgroundColor = Utils.getColor(value) ?? backgroundColor;
        _updateSignatureController();
      },
      'value': (val) {
        value = val;
        _loadSignatureFromValue();
      },
      'disabled': (value) {
        disabled = value ?? false;
        _updateSignatureController();
      },
      'strokeCap': (value) {
        strokeCap = StrokeCap.values.from(value) ?? StrokeCap.butt;
        _updateSignatureController();
      },
      'strokeJoin': (value) {
        strokeJoin = StrokeJoin.values.from(value) ?? StrokeJoin.miter;
        _updateSignatureController();
      },
      'exportBackgroundColor': (value) {
        exportBackgroundColor = Utils.getColor(value);
        _updateSignatureController();
      },
      'exportPenColor': (value) {
        exportPenColor = Utils.getColor(value);
        _updateSignatureController();
      },
    });

  @override
  Map<String, Function> methods() => Map<String, Function>.from(super.methods())
    ..addAll({
      'clear': clearSignature,
    });

  @override
  Map<String, Function> getters() => Map<String, Function>.from(super.getters())
    ..addAll({
      'isEmpty': () => signatureController.isEmpty,
      'value': () => value,
      'getSignatureBytes': () => _cachedSignatureBytes,
      'getSignatureSVG': () => _cachedSignatureSVG,
      'getSignatureJPG': () => _cachedSignatureJPG,
    });

  void clearSignature() {
    signatureController.clear();
    _cachedSignatureBytes = null;
    _cachedSignatureSVG = null;
    _cachedSignatureJPG = null;
    value = null;
  }

  void _updateSignatureController() {
    signatureController = SignatureController(
      penStrokeWidth: penStrokeWidth,
      penColor: penColor,
      exportBackgroundColor: exportBackgroundColor ?? backgroundColor,
      exportPenColor: exportPenColor ?? penColor,
      strokeCap: strokeCap,
      strokeJoin: strokeJoin,
      disabled: disabled,
      onDrawEnd: () {
        value = _convertPointsToBase64(signatureController.points);
        if (signatureController.isNotEmpty) {
            signatureController.toPngBytes().then((bytes) {
            _cachedSignatureBytes = bytes;
          });
          _cachedSignatureSVG = signatureController.toSVG();
          signatureController.toImage().then((image) {
            _cachedSignatureJPG = image;
          });
        }
      },
    );

    if (value != null) {
      _loadSignatureFromValue();
    }
  }

  void _loadSignatureFromValue() {
    if (value != null) {
      final points = _convertBase64ToPoints(value!);
      signatureController.points = points;
    }
  }

  String _convertPointsToBase64(List<Point> points) {
    final List<Map<String, dynamic>> pointsMap = points
        .map((e) => {
              'x': e.offset.dx,
              'y': e.offset.dy,
              'pressure': e.pressure,
              'type': e.type.index,
            })
        .toList();
    return base64Encode(utf8.encode(jsonEncode(pointsMap)));
  }

  List<Point> _convertBase64ToPoints(String base64String) {
    try {
      final List<dynamic> pointsJson =
          jsonDecode(utf8.decode(base64Decode(base64String)));
      return pointsJson
          .map<Point>((point) => Point(
                Offset(point['x'].toDouble(), point['y'].toDouble()),
                PointType.values[point['type']],
                point['pressure'].toDouble(),
              ))
          .toList();
    } catch (e) {
      return <Point>[];
    }
  }
}

class EnsembleSignatureState extends EnsembleWidgetState<EnsembleSignature> {
  @override
  Widget buildWidget(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double signatureHeight = widget.controller.height?.toDouble() ??
            constraints.maxHeight.clamp(200.0, 400.0);
        double signatureWidth = widget.controller.width?.toDouble() ??
            constraints.maxWidth;

        return EnsembleBoxWrapper(
          widget: Signature(
            controller: widget.controller.signatureController,
            backgroundColor: widget.controller.backgroundColor ?? Colors.transparent,
            width: signatureWidth,
            height: signatureHeight,
          ),
          boxController: widget.controller,
          fallbackWidth: signatureWidth,
          fallbackHeight: signatureHeight,
        );
      },
    );
  }
}
