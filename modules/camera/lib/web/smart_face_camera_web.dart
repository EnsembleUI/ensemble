import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:face_camera/face_camera.dart';
import 'face_detection_web.dart' as face_detection show WebFaceDetection;

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
    face_detection.WebFaceDetection.statusMessage,
    face_detection.WebFaceDetection.faceDetected,
    face_detection.WebFaceDetection.faceLeft,
    face_detection.WebFaceDetection.faceTop,
    face_detection.WebFaceDetection.faceWidth,
    face_detection.WebFaceDetection.faceHeight,
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
          face_detection.WebFaceDetection.getCameraController()
                  ?.value
                  .isInitialized ==
              true &&
          face_detection.WebFaceDetection.shouldAutoCapture(
              widget.autoCapture)) {
        face_detection.WebFaceDetection.markAutoCaptured();
        _captureImage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraController =
        face_detection.WebFaceDetection.getCameraController();
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
                        face_detection.WebFaceDetection.getCameras().length > 1)
                      IconButton(
                        icon: const Icon(Icons.switch_camera),
                        color: Colors.white,
                        onPressed: () async {
                          await face_detection.WebFaceDetection.switchCamera();
                          setState(() {});
                        },
                      ),
                    if (widget.showCaptureControl)
                      IconButton(
                        icon: const Icon(Icons.camera),
                        color: Colors.white,
                        iconSize: 32,
                        onPressed: (!widget.autoDisableCaptureControl ||
                                face_detection
                                    .WebFaceDetection.faceDetected.value)
                            ? _captureImage
                            : null,
                        disabledColor: Colors.grey,
                      ),
                    if (widget.showFlashControl &&
                        face_detection.WebFaceDetection.isFlashSupported())
                      IconButton(
                        icon: Icon(
                          face_detection.WebFaceDetection.getFlashMode() ==
                                  FlashMode.off
                              ? Icons.flash_off
                              : Icons.flash_on,
                        ),
                        color: Colors.white,
                        onPressed: () async {
                          final currentMode =
                              face_detection.WebFaceDetection.getFlashMode();
                          final success = await face_detection.WebFaceDetection
                              .setFlashMode(
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
        final previewRatio =
            face_detection.WebFaceDetection.getAspectRatio() ?? 1.0;
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final bool isWider = screenWidth / screenHeight > previewRatio;
        final previewHeight =
            isWider ? screenHeight : screenWidth / previewRatio;
        final previewWidth =
            isWider ? screenHeight * previewRatio : screenWidth;

        final faceLeft = face_detection.WebFaceDetection.faceLeft.value;
        final faceTop = face_detection.WebFaceDetection.faceTop.value;
        final faceWidth = face_detection.WebFaceDetection.faceWidth.value;
        final faceHeight = face_detection.WebFaceDetection.faceHeight.value;
        final faceDetected = face_detection.WebFaceDetection.faceDetected.value;
        final statusMessage =
            face_detection.WebFaceDetection.statusMessage.value;

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
        !face_detection.WebFaceDetection.faceDetected.value) return;
    if (_isCapturing) return;
    _isCapturing = true;
    try {
      final imagePath = await face_detection.WebFaceDetection.takePicture();
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
