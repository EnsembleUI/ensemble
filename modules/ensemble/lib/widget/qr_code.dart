import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// This widget can renders a QR code based on the value passed in
class QRCode extends StatefulWidget
    with Invokable, HasController<QRCodeController, QRCodeState> {
  static const type = 'QRCode';
  QRCode({Key? key}) : super(key: key);

  final QRCodeController _controller = QRCodeController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => QRCodeState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) => _controller.value = Utils.optionalString(value),
      'size': (value) => _controller.size = Utils.optionalInt(value),
      'color': (color) => _controller.color = Utils.getColor(color),
      'dataModuleShape': (value) => _controller.dataModuleShape =
          QrDataModuleShape.values.asNameMap()[value] ??
              QrDataModuleShape.square,
      'eyeShape': (value) => _controller.eyeShape =
          QrEyeShape.values.asNameMap()[value] ?? QrEyeShape.square,
    };
  }
}

class QRCodeController extends BoxController {
  String? value;
  int? size;
  Color? color;
  QrDataModuleShape dataModuleShape = QrDataModuleShape.square;
  QrEyeShape eyeShape = QrEyeShape.square;
}

class QRCodeState extends EWidgetState<QRCode> {
  static const double defaultSize = 160;

  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller.value == null ||
        widget._controller.value!.trim().isEmpty) {
      return Image.asset('assets/images/qr_error.png',
          package: 'ensemble',
          width: widget._controller.size?.toDouble() ?? defaultSize,
          semanticLabel: 'Invalid QR Code');
    }

    return BoxWrapper(
        widget: QrImageView(
            data: widget._controller.value!,
            size: widget._controller.size?.toDouble() ?? defaultSize,
            backgroundColor:
                widget._controller.backgroundColor ?? Colors.transparent,
            dataModuleStyle: QrDataModuleStyle(
              color: widget._controller.color ?? Colors.black,
              dataModuleShape: widget._controller.dataModuleShape,
            ),
            eyeStyle: QrEyeStyle(
              color: widget._controller.color ?? Colors.black,
              eyeShape: widget._controller.eyeShape,
            )),
        boxController: widget._controller,
        ignoresDimension: true // width/height doesn't apply here
        );
  }
}
