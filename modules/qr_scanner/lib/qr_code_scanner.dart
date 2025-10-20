import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/stub/qr_code_scanner.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
    // Convert to mobile_scanner formats
    final List<BarcodeFormat> formats = [];
    for (var format in formatsAllowed) {
      switch (format.toLowerCase()) {
        case 'qrcode':
          formats.add(BarcodeFormat.qrCode);
          break;
        case 'barcode':
          formats.add(BarcodeFormat.code128);
          formats.add(BarcodeFormat.code39);
          formats.add(BarcodeFormat.code93);
          formats.add(BarcodeFormat.codabar);
          formats.add(BarcodeFormat.ean8);
          formats.add(BarcodeFormat.ean13);
          formats.add(BarcodeFormat.upcA);
          formats.add(BarcodeFormat.upcE);
          break;
        // Add other formats as needed
      }
    }
    return formats.isEmpty ? [BarcodeFormat.qrCode] : formats;
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
  MobileScannerController? scannerController;

  @override
  void initState() {
    super.initState();
    scannerController = MobileScannerController(
      facing: widget.controller.initialCamera == CameraFacing.back
          ? CameraFacing.back
          : CameraFacing.front,
      formats: widget.controller.allFormatsAllowed,
    );

    if (widget.controller.onInitialized != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScreenController().executeAction(
          context,
          widget.controller.onInitialized!,
          event: EnsembleEvent(widget.controller),
        );
      });
    }

    widget.controller.qrCodeScannerAction = this;
  }

  @override
  Widget buildWidget(BuildContext context) {
    final cutOutHeight =
        Utils.getDouble(widget.controller.cutOutHeight, fallback: 200);
    final cutOutWidth =
        Utils.getDouble(widget.controller.cutOutWidth, fallback: 200);

    return EnsembleBoxWrapper(
      boxController: widget.controller,
      widget: MobileScanner(
        key: qrKey,
        controller: scannerController,
        scanWindow: Rect.fromCenter(
          center: MediaQuery.of(context).size.center(Offset.zero),
          width: cutOutWidth,
          height: cutOutHeight,
        ),
        onDetect: (capture) {
          if (capture.barcodes.isNotEmpty &&
              widget.controller.onReceived != null) {
            final barcode = capture.barcodes.first;
            final data = {
              'format': barcode.format.name,
              'data': barcode.rawValue,
              'rawBytes': barcode.rawBytes,
            };

            ScreenController().executeAction(
              context,
              widget.controller.onReceived!,
              event: EnsembleEvent(widget.controller, data: data),
            );
          }
        },
        overlayBuilder: (context, constraints) {
          return CustomPaint(
            painter: QRScannerOverlayPainter(
              borderColor: widget.controller.cutOutBorderColor ?? Colors.red,
              borderRadius: Utils.getDouble(
                  widget.controller.cutOutBorderRadius,
                  fallback: 0),
              cutOutSize: cutOutWidth,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }

  @override
  void flipCamera() {
    scannerController?.switchCamera();
  }

  @override
  void pauseCamera() {
    scannerController?.stop();
  }

  @override
  void resumeCamera() {
    scannerController?.start();
  }

  @override
  void toggleFlash() async {
    await scannerController?.toggleTorch();
    widget.controller.isFlashOn = !widget.controller.isFlashOn;
  }

  @override
  void dispose() {
    scannerController?.dispose();
    super.dispose();
  }
}

// Simplified overlay painter that just draws the border
class QRScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double cutOutSize;

  QRScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the rectangle in the center
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: cutOutSize,
      height: cutOutSize,
    );

    // Draw the scanning rectangle border
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw corners instead of full border
    const cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(
      rect.topLeft.translate(0, cornerLength),
      rect.topLeft,
      paint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft.translate(cornerLength, 0),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      rect.topRight.translate(-cornerLength, 0),
      rect.topRight,
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight.translate(0, cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      rect.bottomLeft.translate(0, -cornerLength),
      rect.bottomLeft,
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft.translate(cornerLength, 0),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      rect.bottomRight.translate(-cornerLength, 0),
      rect.bottomRight,
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight.translate(0, -cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
