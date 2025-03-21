import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:face_camera/face_camera.dart';
import 'face_detection_web.dart';

class SmartFaceCameraWeb extends StatefulWidget {
  final String message;
  final TextStyle messageStyle;
  final bool showControls;
  final bool showCaptureControl;
  final bool showFlashControl;
  final bool showCameraLensControl;
  final bool showStatusMessage;
  final IndicatorShape indicatorShape;
  final bool autoDisableCaptureControl;
  final bool autoCapture;
  final Function(String)? onCapture;
  final Function(dynamic)? onError;

  const SmartFaceCameraWeb({
    Key? key,
    this.message = '',
    this.messageStyle = const TextStyle(color: Colors.white),
    this.showControls = true,
    this.showCaptureControl = true,
    this.showFlashControl = true,
    this.showCameraLensControl = true,
    this.showStatusMessage = true,
    this.indicatorShape = IndicatorShape.defaultShape,
    this.autoDisableCaptureControl = false,
    this.autoCapture = false,
    this.onCapture,
    this.onError,
  }) : super(key: key);

  @override
  State<SmartFaceCameraWeb> createState() => _SmartFaceCameraWebState();
}

class _SmartFaceCameraWebState extends State<SmartFaceCameraWeb> {
  bool _isCapturing = false;

  // Group notifiers to simplify adding and removing listeners.
  final List<ValueNotifier<dynamic>> _notifiers = [
    WebFaceDetection.statusMessage,
    WebFaceDetection.faceDetected,
    WebFaceDetection.faceLeft,
    WebFaceDetection.faceTop,
    WebFaceDetection.faceWidth,
    WebFaceDetection.faceHeight,
  ];

  @override
  void initState() {
    super.initState();
    for (final notifier in _notifiers) {
      notifier.addListener(_updateState);
    }
  }

  @override
  void dispose() {
    for (final notifier in _notifiers) {
      notifier.removeListener(_updateState);
    }
    super.dispose();
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
      if (widget.autoCapture &&
          WebFaceDetection.getCameraController()?.value.isInitialized == true &&
          WebFaceDetection.shouldAutoCapture(widget.autoCapture)) {
        WebFaceDetection.markAutoCaptured();
        _captureImage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraController = WebFaceDetection.getCameraController();
    if (cameraController == null ||
        !mounted ||
        !cameraController.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildCameraPreview(cameraController),
            if (widget.message.isNotEmpty)
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(widget.message, style: widget.messageStyle),
                  ),
                ),
              ),
            if (widget.showControls)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (widget.showCameraLensControl &&
                        WebFaceDetection.getCameras().length > 1)
                      IconButton(
                        icon: const Icon(Icons.switch_camera),
                        color: Colors.white,
                        onPressed: () async {
                          await WebFaceDetection.switchCamera();
                          setState(() {});
                        },
                      ),
                    if (widget.showCaptureControl)
                      IconButton(
                        icon: const Icon(Icons.camera),
                        color: Colors.white,
                        iconSize: 32,
                        onPressed: (!widget.autoDisableCaptureControl ||
                                WebFaceDetection.faceDetected.value)
                            ? _captureImage
                            : null,
                        disabledColor: Colors.grey,
                      ),
                    if (widget.showFlashControl &&
                        WebFaceDetection.isFlashSupported())
                      IconButton(
                        icon: Icon(
                          WebFaceDetection.getFlashMode() == FlashMode.off
                              ? Icons.flash_off
                              : Icons.flash_on,
                        ),
                        color: Colors.white,
                        onPressed: () async {
                          final currentMode = WebFaceDetection.getFlashMode();
                          final success = await WebFaceDetection.setFlashMode(
                            currentMode == FlashMode.off
                                ? FlashMode.torch
                                : FlashMode.off,
                          );
                          if (success) setState(() {});
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(CameraController cameraController) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewRatio = WebFaceDetection.getAspectRatio() ?? 1.0;
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final bool isWider = screenWidth / screenHeight > previewRatio;
        final previewHeight =
            isWider ? screenHeight : screenWidth / previewRatio;
        final previewWidth =
            isWider ? screenHeight * previewRatio : screenWidth;

        final faceLeft = WebFaceDetection.faceLeft.value;
        final faceTop = WebFaceDetection.faceTop.value;
        final faceWidth = WebFaceDetection.faceWidth.value;
        final faceHeight = WebFaceDetection.faceHeight.value;
        final faceDetected = WebFaceDetection.faceDetected.value;
        final statusMessage = WebFaceDetection.statusMessage.value;

        return Stack(
          children: [
            Center(
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                  child: CameraPreview(cameraController),
                ),
              ),
            ),
            if (faceLeft != null &&
                faceTop != null &&
                faceWidth != null &&
                faceHeight != null)
              Positioned(
                left:
                    (screenWidth - previewWidth) / 2 + faceLeft * previewWidth,
                top: (screenHeight - previewHeight) / 2 +
                    faceTop * previewHeight,
                child: Container(
                  width: faceWidth * previewWidth,
                  height: faceHeight * previewHeight,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: faceDetected ? Colors.green : Colors.red,
                      width: 3.0,
                    ),
                    borderRadius:
                        _getIndicatorBorderRadius(widget.indicatorShape),
                  ),
                ),
              ),
            if (statusMessage.isNotEmpty &&
                widget.showStatusMessage &&
                faceLeft != null &&
                faceTop != null &&
                faceWidth != null &&
                faceHeight != null)
              Positioned(
                left:
                    (screenWidth - previewWidth) / 2 + faceLeft * previewWidth,
                top: (screenHeight - previewHeight) / 2 +
                    faceTop * previewHeight +
                    faceHeight * previewHeight +
                    10,
                width: faceWidth * previewWidth,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  BorderRadius _getIndicatorBorderRadius(IndicatorShape shape) {
    return shape == IndicatorShape.circle
        ? BorderRadius.circular(100)
        : BorderRadius.circular(8);
  }

  Future<void> _captureImage() async {
    if (widget.autoDisableCaptureControl &&
        !WebFaceDetection.faceDetected.value) return;
    if (_isCapturing) return;
    _isCapturing = true;
    try {
      final imagePath = await WebFaceDetection.takePicture();
      if (imagePath != null) widget.onCapture?.call(imagePath);
    } catch (e) {
      if (!e.toString().contains('after being disposed')) {
        widget.onError?.call(e);
      }
    } finally {
      _isCapturing = false;
    }
  }
}
