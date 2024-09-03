import 'dart:io';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/stub/qr_code_scanner.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class EnsembleQRCodeScannerImpl
    extends EnsembleWidget<EnsembleQRCodeScannerController>
    implements EnsembleQRCodeScanner {
  const EnsembleQRCodeScannerImpl._(super.controller, {super.key});

  factory EnsembleQRCodeScannerImpl.build(dynamic controller) =>
      EnsembleQRCodeScannerImpl._(controller is EnsembleQRCodeScannerController
          ? controller
          : EnsembleQRCodeScannerController());

  @override
  State<StatefulWidget> createState() => EnsembleQRCodeScannerState();
}

class EnsembleQRCodeScannerController extends EnsembleBoxController {
  bool isFlashOn = false;
  int? cutOutBorderRadius;
  int? cutOutBorderLength;
  int? cutOutBorderWidth;
  int? cutOutHeight;
  int? cutOutWidth;
  Color? cutOutBorderColor;
  EdgeInsets? overlayMargin;
  QRCodeScannerAction? qrCodeScannerAction;
  EnsembleAction? onReceived;
  EnsembleAction? onInitialized;
  EnsembleAction? onPermissionSet;
  CameraFacing initialCamera = CameraFacing.back;
  List<String> formatsAllowed = [];
  Color? overlayColor;

  List<BarcodeFormat> get allFormatsAllowed {
    final allFormats = formatsAllowed
        .map((format) => BarcodeFormat.values.from(format))
        .whereType<BarcodeFormat>()
        .toList();
    return allFormats;
  }

  @override
  Map<String, Function> getters() {
    return {
      'formatsAllowed': () => formatsAllowed,
      'initialCamera': () => initialCamera.name,
      'isFlashOn': () => isFlashOn,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'flipCamera': () => qrCodeScannerAction?.flipCamera(),
      'toggleFlash': () => qrCodeScannerAction?.toggleFlash(),
      'pauseCamera': () => qrCodeScannerAction?.pauseCamera(),
      'resumeCamera': () => qrCodeScannerAction?.resumeCamera(),
    };
  }

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'initialCamera': (value) => initialCamera =
          CameraFacing.values.from(Utils.optionalString(value)) ??
              CameraFacing.back,
      'formatsAllowed': (value) => formatsAllowed =
          Utils.getListOfStrings(value)?.whereType<String>().toList() ?? [],
      'overlayMargin': (value) => overlayMargin = Utils.optionalInsets(value),
      'cutOutBorderWidth': (value) =>
          cutOutBorderWidth = Utils.optionalInt(value),
      'cutOutBorderRadius': (value) =>
          cutOutBorderRadius = Utils.optionalInt(value),
      'cutOutBorderLength': (value) =>
          cutOutBorderLength = Utils.optionalInt(value),
      'cutOutHeight': (value) => cutOutHeight = Utils.optionalInt(value),
      'cutOutWidth': (value) => cutOutWidth = Utils.optionalInt(value),
      'overlayColor': (color) => overlayColor = Utils.getColor(color),
      'cutOutBorderColor': (color) => cutOutBorderColor = Utils.getColor(color),
      'onInitialized': (func) =>
          onInitialized = EnsembleAction.from(func, initiator: this),
      'onReceived': (func) =>
          onReceived = EnsembleAction.from(func, initiator: this),
      'onPermissionSet': (func) =>
          onPermissionSet = EnsembleAction.from(func, initiator: this),
    });
}

mixin QRCodeScannerAction on EnsembleWidgetState<EnsembleQRCodeScannerImpl> {
  void flipCamera();
  void toggleFlash();
  void pauseCamera();
  void resumeCamera();
}

class EnsembleQRCodeScannerState
    extends EnsembleWidgetState<EnsembleQRCodeScannerImpl>
    with QRCodeScannerAction {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      pauseCamera();
    }
    resumeCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    widget.controller.qrCodeScannerAction = this;
  }

  @override
  void didUpdateWidget(covariant EnsembleQRCodeScannerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);

    widget.controller.qrCodeScannerAction = this;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return EnsembleBoxWrapper(
      boxController: widget.controller,
      widget: QRView(
        key: qrKey,
        cameraFacing: widget.controller.initialCamera,
        formatsAllowed: widget.controller.allFormatsAllowed,
        overlayMargin: widget.controller.overlayMargin ?? EdgeInsets.zero,
        overlay: QrScannerOverlayShape(
          borderColor: widget.controller.cutOutBorderColor ?? Colors.red,
          // borderColor: Colors.yellow,
          overlayColor: widget.controller.overlayColor ??
              const Color.fromRGBO(0, 0, 0, 80),
          borderRadius: Utils.getDouble(widget.controller.cutOutBorderRadius,
              fallback: 0),
          borderLength: Utils.getDouble(widget.controller.cutOutBorderLength,
              fallback: 40),
          borderWidth: Utils.getDouble(widget.controller.cutOutBorderWidth,
              fallback: 3.0),
          cutOutHeight:
              Utils.getDouble(widget.controller.cutOutHeight, fallback: 200),
          cutOutWidth:
              Utils.getDouble(widget.controller.cutOutWidth, fallback: 200),
        ),
        onQRViewCreated: _onQRViewCreated,
        onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      qrController = controller;
    });

    if (widget.controller.onInitialized != null) {
      ScreenController().executeAction(
        context,
        widget.controller.onInitialized!,
        event: EnsembleEvent(widget.controller),
      );
    }

    qrController?.scannedDataStream.listen((scanData) {
      if (widget.controller.onReceived != null) {
        final data = {
          'format': scanData.format.name,
          'data': scanData.code,
          'rawBytes': scanData.rawBytes,
        };

        ScreenController().executeAction(
          context,
          widget.controller.onReceived!,
          event: EnsembleEvent(widget.controller, data: data),
        );
      }
    });
  }

  void _onPermissionSet(
      BuildContext context, QRViewController ctrl, bool status) {
    if (widget.controller.onPermissionSet != null) {
      ScreenController().executeAction(
        context,
        widget.controller.onPermissionSet!,
        event: EnsembleEvent(widget.controller, data: {'status': status}),
      );
    }
  }

  @override
  void flipCamera() {
    qrController?.flipCamera();
  }

  @override
  void pauseCamera() {
    qrController?.pauseCamera();
  }

  @override
  void resumeCamera() {
    qrController?.resumeCamera();
  }

  @override
  void toggleFlash() async {
    await qrController?.toggleFlash();
    widget.controller.isFlashOn = !widget.controller.isFlashOn;
  }
}
