import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:ensemble/action/toast_actions.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/widget/icon.dart' as iconframework;
import 'package:ensemble/framework/widget/toast.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble/framework/model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:video_player/video_player.dart';

enum CameraMode { photo, video, both }

enum InitialCamera { back, front }

class Camera extends StatefulWidget
    with Invokable, HasController<MyCameraController, CameraState> {
  static const type = 'Camera';
  Camera({
    Key? key,
    this.onCapture,
    this.onComplete,
  }) : super(key: key);

  final Function? onCapture;
  final Function? onComplete;

  final MyCameraController _controller = MyCameraController();

  @override
  State<StatefulWidget> createState() => CameraState();

  @override
  MyCameraController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {
      'files': () => _controller.files.map((e) => e.toJson()).toList(),
      'currentFile': () => _controller.currentFile?.toJson(),
      'latitude': () => _controller.position?.latitude,
      'longitude': () => _controller.position?.longitude,
      'speed': () => _controller.position?.speed,
      'angle': () => _controller.angle,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'clear': () => _controller.files.clear(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'instantPreview': (value) =>
          _controller.instantPreview = Utils.getBool(value, fallback: false),
      'mode': (value) => _controller.initCameraMode(value),
      'initialCamera': (value) => _controller.initCameraOption(value),
      'allowGalleryPicker': (value) =>
          _controller.allowGallery = Utils.getBool(value, fallback: false),
      'allowCameraRotate': (value) =>
          _controller.allowCameraRotate = Utils.getBool(value, fallback: false),
      'allowFlashControl': (value) =>
          _controller.allowFlashControl = Utils.getBool(value, fallback: false),
      'minCount': (value) => _controller.minCount = Utils.optionalInt(value),
      'maxCount': (value) => _controller.maxCount = Utils.optionalInt(value),
      'preview': (value) =>
          _controller.preview = Utils.getBool(value, fallback: false),
      'minCountMessage': (value) =>
          _controller.minCountMessage = Utils.optionalString(value),
      'maxCountMessage': (value) =>
          _controller.maxCountMessage = Utils.optionalString(value),
      'permissionDeniedMessage': (value) =>
          _controller.permissionDeniedMessage = Utils.optionalString(value),
      'nextButtonLabel': (value) =>
          _controller.nextButtonLabel = Utils.optionalString(value),
      'accessButtonLabel': (value) =>
          _controller.accessButtonLabel = Utils.optionalString(value),
      'galleryButtonLabel': (value) =>
          _controller.galleryButtonLabel = Utils.optionalString(value),
      'imagePickerIcon': (value) =>
          _controller.imagePickerIcon = Utils.getIcon(value),
      'cameraRotateIcon': (value) =>
          _controller.cameraRotateIcon = Utils.getIcon(value),
      'focusIcon': (value) => _controller.focusIcon = Utils.getIcon(value),
      'assistAngle': (value) =>
          _controller.assistAngle = Utils.getBool(value, fallback: false),
      'assistSpeed': (value) =>
          _controller.assistSpeed = Utils.getBool(value, fallback: false),
      'maxSpeed': (value) =>
          _controller.maxSpeed = Utils.getDouble(value, fallback: 30),
      'maxAngle': (value) =>
          _controller.maxAngle = Utils.getDouble(value, fallback: 180),
      'minAngle': (value) =>
          _controller.minAngle = Utils.getDouble(value, fallback: -180),
      'assistAngleMessage': (value) =>
          _controller.assistAngleMessage = Utils.optionalString(value),
      'assistSpeedMessage': (value) =>
          _controller.assistSpeedMessage = Utils.optionalString(value),
      'autoCaptureInterval': (value) =>
          _controller.autoCaptureInterval = Utils.getInt(value, fallback: -1),
      'enableMicrophone': (value) =>
          _controller.enableMicrophone = Utils.getBool(value, fallback: true),
    };
  }
}

class MyCameraController extends WidgetController {
  CameraController? cameraController;

  CameraMode mode = CameraMode.both;
  InitialCamera initialCamera = InitialCamera.back;
  bool allowGallery = false;
  bool allowCameraRotate = false;
  bool allowFlashControl = false;
  int? minCount;
  int? maxCount;
  bool instantPreview = false;
  bool preview = false;
  String? minCountMessage;
  String? maxCountMessage;
  String? permissionDeniedMessage;
  double minAngle = -180;
  double maxAngle = 180;
  double maxSpeed = 30; // Speed in km/hr
  String? nextButtonLabel;
  String? accessButtonLabel;
  String? galleryButtonLabel;
  bool assistAngle = false;
  bool assistSpeed = false;
  String? assistAngleMessage;
  String? assistSpeedMessage;
  IconModel? imagePickerIcon;
  IconModel? cameraRotateIcon;
  IconModel? focusIcon;
  bool enableMicrophone = true;

  int autoCaptureInterval = -1;
  ValueNotifier<int> intervalCountdown = ValueNotifier(-1);
  bool intervalPause = true;

  List<File> files = [];
  File? currentFile;
  Position? position;
  double? angle;

  void initCameraOption(String? data) {
    if (data == null) return;
    if (data.toLowerCase() == 'front') initialCamera = InitialCamera.front;
    if (data.toLowerCase() == 'back') initialCamera = InitialCamera.back;

    notifyListeners();
  }

  void initCameraMode(String? data) {
    if (data == null) return;
    if (data.toLowerCase() == 'photo') mode = CameraMode.photo;
    if (data.toLowerCase() == 'video') mode = CameraMode.video;

    notifyListeners();
  }
}

class CameraState extends EWidgetState<Camera> with WidgetsBindingObserver {
  final ImagePicker imagePicker = ImagePicker();
  List<CameraDescription> cameras = [];
  late PageController pageController;

  bool isFrontCamera = false;
  bool showPreviewPage = false;
  bool isRecording = false;
  bool hasPermission = false;
  bool isLoading = true;
  int currentModeIndex = 0;

  List<CameraMode> modes = [];

  late Color iconColor = Theme.of(context).colorScheme.primary;
  double iconSize = 24.0;

  int seconds = 0;
  bool isTimerRunning = false;
  Timer? timer;

  bool _isVideoCameraSelected = false;
  final ValueNotifier<FocusState> _focusState = ValueNotifier(FocusState.none);

  Offset? _offset;
  bool isFullScreen = true;

  ValueNotifier<double?> phoneAngle = ValueNotifier(null);
  ValueNotifier<double?> phoneSpeed = ValueNotifier(null);
  StreamSubscription? accelerometerSub;
  StreamSubscription? positionSub;
  final previewPageController = PageController();

  final _flashPageController = PageController();
  final flashModes = [FlashMode.off, FlashMode.auto, FlashMode.always];
  final flashIcons = [Icons.flash_off, Icons.flash_auto, Icons.flash_on];

  GeolocatorPlatform locator = GeolocatorPlatform.instance;

  late int currentIndex;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    initCameras();

    if (widget._controller.assistAngle) {
      initAccelerometerSub();
    }

    if (widget._controller.assistSpeed) {
      initGeoLocator();
    }

    if (widget._controller.autoCaptureInterval > 0) {
      initAutoCapture();
    }

    initPageController();
  }

  void initCameras() async {
    try {
      cameras = await availableCameras();
      setCameraInit();
    } catch (e) {
      if (e is CameraException && e.code == 'CameraAccessDenied') {
        hasPermission = false;
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  void initAccelerometerSub() {
    accelerometerSub = accelerometerEvents.listen((AccelerometerEvent event) {
      double radians = math.atan2(event.y, event.z);
      widget._controller.angle = phoneAngle.value = radians * 180 / math.pi;
    });
  }

  void initPageController() {
    setCameraMode();
    pageController =
        PageController(viewportFraction: 0.25, initialPage: currentModeIndex);
  }

  void initAutoCapture() {
    widget._controller.intervalCountdown.value =
        widget._controller.autoCaptureInterval;
    widget._controller.intervalPause = false;
    setState(() {});
    Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (!mounted || !canCapture()) {
          timer.cancel();
          widget._controller.intervalPause = true;
          if (mounted) setState(() {});
          return;
        }
        if (widget._controller.intervalPause) return;
        if (widget._controller.intervalCountdown.value > 0) {
          widget._controller.intervalCountdown.value--;
        } else {
          if (!showPreviewPage) {
            capture();
          }
          widget._controller.intervalCountdown.value =
              widget._controller.autoCaptureInterval;
        }
      },
    );
  }

  Future<void> initGeoLocator() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      permission = await GeolocatorPlatform.instance.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      startLocationStream();
      bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) {
        int count = 0;
        Timer.periodic(const Duration(seconds: 2), (timer) async {
          isLocationEnabled = await Geolocator.isLocationServiceEnabled();
          if (isLocationEnabled) {
            startLocationStream();
            timer.cancel();
          } else if (++count >= 5) {
            timer.cancel();
          }
        });
      }
    }
  }

  Future<void> startLocationStream() async {
    await positionSub?.cancel();
    positionSub = locator
        .getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    )
        .listen((Position position) async {
      final updatedPosition = await locator.getCurrentPosition();
      final velocity = (position.speed + updatedPosition.speed) / 2;
      phoneSpeed.value = velocity * 18 / 5;
      widget._controller.position = position;
    });
  }

  Future<void> setCamera({CameraDescription? cameraDescription}) async {
    CameraDescription targetCamera = cameraDescription ?? cameras[0];

    widget._controller.cameraController = CameraController(
      targetCamera,
      ResolutionPreset.veryHigh,
      enableAudio: widget._controller.enableMicrophone,
    );

    try {
      await widget._controller.cameraController!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      // Handle camera initialization errors, e.g., log them or show a user-friendly message.
      debugPrint("Camera initialization error: $e");
    }
  }

  void setCameraInit() {
    final initialCamera = widget._controller.initialCamera;
    final backCamera = cameras.firstWhereOrNull(
        (camera) => camera.lensDirection == CameraLensDirection.back);
    final frontCamera = cameras.firstWhereOrNull(
        (camera) => camera.lensDirection == CameraLensDirection.front);

    if (initialCamera == InitialCamera.back && backCamera != null) {
      setCamera(cameraDescription: backCamera);
    } else if (initialCamera == InitialCamera.front && frontCamera != null) {
      setCamera(cameraDescription: frontCamera);
      isFrontCamera = true;
      setState(() {});
    } else {
      setCamera();
    }
  }

  void setCameraMode() {
    if (widget._controller.mode == CameraMode.both) {
      modes.addAll([CameraMode.photo, CameraMode.video]);
    } else if (widget._controller.mode == CameraMode.video) {
      modes.add(CameraMode.video);
      _isVideoCameraSelected = true;
    } else {
      modes.add(CameraMode.photo);
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget._controller.cameraController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    accelerometerSub?.cancel();
    positionSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController =
        widget._controller.cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      setCamera(cameraDescription: cameraController.description);
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget._controller.cameraController == null ||
        !widget._controller.cameraController!.value.isInitialized) {
      return Container();
    }
    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          if (showPreviewPage) {
            if (widget._controller.cameraController == null) {
              setState(() {
                showPreviewPage = false;
              });
            } else {
              setState(() {
                widget._controller.cameraController!.resumePreview();
                showPreviewPage = false;
              });
            }
          } else {
            Navigator.pop(context, widget._controller.files);
          }
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: showPreviewPage ? fullImagePreview() : cameraView(),
        ),
      ),
    );
  }

  Widget cameraView() {
    return Stack(
      children: [
        kIsWeb
            ? Center(
                child: AspectRatio(
                  aspectRatio:
                      widget.controller.cameraController!.value.aspectRatio,
                  child: widget.controller.cameraController!.buildPreview(),
                ),
              )
            : CameraPreview(
                widget._controller.cameraController!,
                child: LayoutBuilder(builder: (context, constraints) {
                  return GestureDetector(
                    onTapUp: kIsWeb
                        ? null
                        : (details) => onViewFinderTap(details, constraints),
                    onScaleUpdate: (details) async {
                      final zoom = details.scale.clamp(1.0, 2.0);
                      widget._controller.cameraController?.setZoomLevel(zoom);
                    },
                  );
                }),
              ),
        imagePreviewButton(),
        Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget._controller.files.isNotEmpty)
                  nextButton(
                    buttontitle: widget._controller.preview
                        ? buttonLabel('Next')
                        : buttonLabel('Done'),
                    imagelength: widget._controller.files.length.toString(),
                    onTap: () {
                      if (widget._controller.preview) {
                        if (widget._controller.cameraController != null) {
                          widget._controller.cameraController!.pausePreview();
                        }
                        setState(() {
                          currentIndex = widget._controller.files.length;
                          showPreviewPage = true;
                        });
                      } else {
                        if (widget._controller.minCount != null &&
                            (widget._controller.files.length <
                                widget._controller.minCount!)) {
                          final errorMessage = widget
                                  ._controller.minCountMessage ??
                              Utils.translateWithFallback(
                                  'ensemble.input.minCountMessage',
                                  'Minimum ${widget._controller.minCount} capture are required');
                          ToastController().showToast(
                              context,
                              ShowToastAction(
                                  type: ToastType.error,
                                  message: errorMessage,
                                  alignment: Alignment.topCenter,
                                  dismissible: true,
                                  duration: 3),
                              null);
                          return;
                        }
                        Navigator.pop(context, widget._controller.files);
                        widget.onComplete?.call();
                      }
                    },
                  ),
                const SizedBox(height: 8),
                mediaThumbnail(),
                cameraButton(),
              ],
            )),
        ValueListenableBuilder(
          valueListenable: _focusState,
          builder: (context, state, child) {
            if (state == FocusState.success) {
              return Positioned(
                left: _offset!.dx,
                top: _offset!.dy,
                child: widget._controller.focusIcon != null
                    ? iconframework.Icon.fromModel(
                        widget._controller.focusIcon!)
                    : Icon(Icons.filter_tilt_shift, color: iconColor, size: 48),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        ValueListenableBuilder<int>(
          valueListenable: widget._controller.intervalCountdown,
          builder: (context, value, child) {
            if (value <= 0 || widget._controller.intervalPause) {
              return const SizedBox.shrink();
            }
            return Center(
                child: Text(
              value.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2.0, 2.0),
                    blurRadius: 3.0,
                    color: Colors.black,
                  ),
                ],
              ),
            ));
          },
        ),
        if (modes.elementAt(currentModeIndex) == CameraMode.photo)
          Align(
            alignment: const Alignment(0.0, -0.8),
            child: ValueListenableBuilder<double?>(
              valueListenable: phoneAngle,
              builder: (context, angle, child) {
                if (angle != null &&
                    (angle < widget._controller.minAngle ||
                        angle > widget._controller.maxAngle)) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: iconColor),
                        color: Colors.black,
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        getAssistAngleMessage(),
                        style: TextStyle(color: iconColor, fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        if (modes.elementAt(currentModeIndex) == CameraMode.video)
          Align(
            alignment: const Alignment(0.0, -0.8),
            child: ValueListenableBuilder<double?>(
              valueListenable: phoneSpeed,
              builder: (context, speed, child) {
                if (speed != null && speed > widget._controller.maxSpeed) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: iconColor),
                        color: Colors.black,
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        getAssistSpeedMessage(),
                        style: TextStyle(color: iconColor, fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          )
      ],
    );
  }

  Widget fullImagePreview() {
    return GestureDetector(
      onTap: () {
        setState(() {
          isFullScreen = !isFullScreen;
        });
      },
      child: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            PageView.builder(
              controller: previewPageController,
              itemCount: widget._controller.files.length,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              itemBuilder: (BuildContext context, int index) {
                final file = widget._controller.files.elementAt(index);

                return kIsWeb
                    ? DisplayMediaWeb(
                        file: file,
                        aspectRatio: widget
                            .controller.cameraController?.value.aspectRatio)
                    : Center(
                        child: file.getMediaType() == MediaType.image
                            ? Image.file(file.toFile()!)
                            : InlineVideoPlayer(
                                file: file,
                              ));
              },
            ),
            isFullScreen
                ? appbar(
                    backArrowAction: () {
                      if (widget._controller.cameraController != null) {
                        widget._controller.cameraController!.resumePreview();
                      }
                      setState(() {
                        showPreviewPage = false;
                      });
                    },
                    deleteButtonAction: deleteImages,
                  )
                : const SizedBox.shrink(),
            Visibility(
              visible: isFullScreen,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (widget._controller.minCount != null &&
                            (widget._controller.files.length <
                                widget._controller.minCount!)) {
                          final errorMessage = widget
                                  ._controller.minCountMessage ??
                              Utils.translateWithFallback(
                                  'ensemble.input.minCountMessage',
                                  'Minimum ${widget._controller.minCount} capture are required');
                          ToastController().showToast(
                              context,
                              ShowToastAction(
                                  type: ToastType.error,
                                  message: errorMessage,
                                  alignment: Alignment.topCenter,
                                  dismissible: true,
                                  duration: 3),
                              null);
                          return;
                        }
                        Navigator.pop(context, widget._controller.files);
                        widget.onComplete?.call();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(24.0)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 4.0),
                        child: Text(
                          'Done',
                          style: TextStyle(
                              color:
                                  hasPermission ? Colors.black : Colors.white,
                              fontSize: 18.0,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                        color: Colors.black.withOpacity(0.4),
                        child: mediaThumbnail(isBorderView: true)),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget permissionDeniedView() {
    return Scaffold(
      body: Column(
        children: [
          imagePreviewButton(),
          const Spacer(),
          Text(
            widget._controller.permissionDeniedMessage ??
                'To capture photos and videos, allow access to your camera.',
          ),
          const Spacer(),
          mediaThumbnail(),
          ElevatedButton(
            onPressed: selectImage,
            child: Text(widget._controller.galleryButtonLabel ??
                Utils.translateWithFallback(
                    'ensemble.input.galleryButtonLabel', 'Pick from gallery')),
          ),
        ],
      ),
    );
  }

  Widget mediaThumbnail({bool isBorderView = false}) {
    return SizedBox(
      height: 82,
      width: MediaQuery.of(context).size.width,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: widget._controller.files.length,
        itemBuilder: (context, index) {
          final file = widget._controller.files.elementAt(index);
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: GestureDetector(
              onTap: widget._controller.preview
                  ? () {
                      if (!showPreviewPage) {
                        setState(() {
                          showPreviewPage = true;
                          currentIndex = index;
                        });
                      }
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () => previewPageController.animateToPage(index,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.ease),
                      );
                    }
                  : null,
              child: Container(
                width: 72.0,
                height: 82.0,
                decoration: BoxDecoration(
                  color: file.getMediaType() == MediaType.video
                      ? Colors.black.withOpacity(0.3)
                      : Colors.transparent,
                  border: isBorderView
                      ? currentIndex == index
                          ? Border.all(color: iconColor, width: 3.0)
                          : Border.all(color: Colors.transparent, width: 3.0)
                      : Border.all(color: Colors.transparent, width: 3.0),
                  borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                ),
                child: ClipRRect(
                    borderRadius: BorderRadius.all(isBorderView
                        ? const Radius.circular(0.0)
                        : const Radius.circular(5.0)),
                    child: kIsWeb
                        ? DisplayMediaWeb(file: file, isThumbnail: true)
                        : file.getMediaType() == MediaType.image
                            ? Image.file(
                                file.toFile()!,
                                fit: BoxFit.cover,
                                key: file.path == null
                                    ? null
                                    : ValueKey(file.path),
                              )
                            : const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                              )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget appbar(
      {required void Function()? backArrowAction,
      required void Function()? deleteButtonAction}) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          buttons(
              onPressed: backArrowAction,
              icon: Icon(
                Icons.arrow_back,
                color: iconColor,
                size: iconSize,
              ),
              shadowColor: Colors.black54),
          buttons(
              onPressed: deleteButtonAction,
              icon: Icon(
                Icons.delete_sharp,
                color: iconColor,
                size: iconSize,
              ),
              shadowColor: Colors.black54),
        ],
      ),
    );
  }

  Widget cameraButton() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (modes.length > 1) silderView(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                widget._controller.allowGallery
                    ? buttons(
                        icon: widget._controller.imagePickerIcon != null
                            ? iconframework.Icon.fromModel(
                                widget._controller.imagePickerIcon!)
                            : Icon(Icons.photo_size_select_actual_outlined,
                                size: iconSize, color: iconColor),
                        backgroundColor: Colors.white.withOpacity(0.1),
                        onPressed: selectImage,
                      )
                    : const SizedBox.shrink(),
                InkWell(
                  onTap: capture,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.circle,
                        color: _isVideoCameraSelected
                            ? Colors.white
                            : Colors.white38,
                        size: 80,
                      ),
                      Icon(
                        Icons.circle,
                        color:
                            _isVideoCameraSelected ? Colors.red : Colors.white,
                        size: 65,
                      ),
                      _isVideoCameraSelected && isRecording
                          ? const Icon(
                              Icons.stop_rounded,
                              color: Colors.white,
                              size: 32,
                            )
                          : Container(),
                    ],
                  ),
                ),
                widget._controller.allowCameraRotate && cameras.length > 1
                    ? buttons(
                        icon: widget._controller.cameraRotateIcon != null
                            ? iconframework.Icon.fromModel(
                                widget._controller.cameraRotateIcon!)
                            : Icon(
                                Icons.flip_camera_ios_outlined,
                                size: iconSize,
                                color: iconColor,
                              ),
                        backgroundColor: Colors.white.withOpacity(0.1),
                        onPressed: () async {
                          try {
                            if (cameras.length <= 1) return;
                            currentModeIndex = 0;
                            setState(() {
                              isLoading = true;
                            });
                            await widget._controller.cameraController
                                ?.dispose();

                            if (isFrontCamera) {
                              final back = cameras.firstWhere((camera) =>
                                  camera.lensDirection ==
                                  CameraLensDirection.back);
                              setCamera(cameraDescription: back);
                              isFrontCamera = false;
                            } else {
                              final front = cameras.firstWhere((camera) =>
                                  camera.lensDirection ==
                                  CameraLensDirection.front);
                              setCamera(cameraDescription: front);
                              isFrontCamera = true;
                            }
                            setState(() {
                              isLoading = false;
                            });
                          } on Exception catch (_) {
                            Navigator.pop(context);
                          }
                        })
                    : SizedBox(width: iconSize * 2, height: iconSize * 2)
              ],
            ),
          ],
        ),
      ),
    );
  }

  void capture() async {
    if (!canCapture()) return;
    File? file;
    if (modes[currentModeIndex] == CameraMode.video) {
      if (isRecording) {
        file = await stopVideoRecording();
      } else {
        await startVideoRecording();
      }
    } else {
      file = await takePicture();
    }
    if (file == null) return;
    widget._controller.files.insert(0, file);
    widget._controller.currentFile = file;
    setState(() {});
    widget.onCapture?.call();

    if (widget._controller.instantPreview) {
      if (widget._controller.cameraController != null) {
        widget._controller.cameraController!.pausePreview();
      }
      setState(() {
        currentIndex = widget._controller.files.length;
        showPreviewPage = true;
      });
    }
  }

  bool canCapture() {
    if (!(widget._controller.maxCount != null &&
        (widget._controller.files.length + 1) > widget._controller.maxCount!)) {
      return true;
    }

    final errorMessage = widget._controller.maxCountMessage ??
        Utils.translateWithFallback('ensemble.input.maxCountMessage',
            'Maximum ${widget._controller.maxCount} files can be selected');
    ToastController().showToast(
        context,
        ShowToastAction(
            type: ToastType.error,
            message: errorMessage,
            alignment: Alignment.topCenter,
            dismissible: true,
            duration: 3),
        null);
    return false;
  }

  Widget silderView() {
    if (_isVideoCameraSelected) {
      Future.delayed(
        const Duration(milliseconds: 100),
        () => pageController.animateToPage(1,
            duration: const Duration(milliseconds: 100), curve: Curves.easeIn),
      );
    }
    return SizedBox(
      height: 20,
      child: PageView.builder(
        scrollDirection: Axis.horizontal,
        controller: pageController,
        onPageChanged: (index) {
          if (isRecording) return;
          _isVideoCameraSelected = modes.elementAt(index) == CameraMode.video;
          setState(() {
            currentModeIndex = index;
          });
        },
        itemCount: modes.length,
        itemBuilder: ((context, index) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: index == currentModeIndex ||
                    widget._controller.mode == CameraMode.video
                ? 1
                : 0.5,
            child: Center(
              child: InkWell(
                onTap: () {
                  if (isRecording) return;
                  _isVideoCameraSelected =
                      modes.elementAt(index) == CameraMode.video;
                  setState(() {
                    currentModeIndex = index;
                  });
                  pageController.animateToPage(index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeIn);
                },
                child: Text(
                  modes[index].name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black,
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget imagePreviewButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          buttons(
            icon: Icon(Icons.close, size: iconSize, color: iconColor),
            backgroundColor: Colors.white.withOpacity(0.1),
            onPressed: () {
              widget._controller.cameraController?.pausePreview();
              Navigator.pop(context, widget._controller.files);
            },
          ),
          isRecording ? timerWidget(seconds) : const SizedBox(),
          Row(
            children: [
              widget._controller.allowFlashControl
                  ? SizedBox(
                      height: 52,
                      width: 52,
                      child: PageView.builder(
                        scrollDirection: Axis.vertical,
                        physics: const NeverScrollableScrollPhysics(),
                        controller: _flashPageController,
                        itemCount: flashIcons.length,
                        itemBuilder: (context, index) {
                          return IconButton(
                              onPressed: () {
                                final page = (index + 1) % flashIcons.length;
                                _flashPageController.animateToPage(page,
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.ease);
                                widget._controller.cameraController
                                    ?.setFlashMode(flashModes.elementAt(page));
                              },
                              icon: Icon(flashIcons.elementAt(index)),
                              color: Colors.white);
                        },
                      ),
                    )
                  : SizedBox(width: iconSize),
              widget._controller.autoCaptureInterval != -1
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          widget._controller.intervalPause =
                              !widget._controller.intervalPause;
                        });
                      },
                      icon: Icon(
                        widget._controller.intervalPause
                            ? Icons.timer_off
                            : Icons.timer,
                        color: Colors.white,
                      ),
                    )
                  : const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }

  Widget nextButton(
      {required String buttontitle,
      String? imagelength,
      void Function()? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(color: Colors.white),
            borderRadius: BorderRadius.circular(24.0)),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              buttontitle,
              style: TextStyle(
                  color: hasPermission ? Colors.black : Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(
              width: 5.0,
            ),
            Container(
              height: 24,
              width: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromRGBO(20, 20, 20, 0.3),
              ),
              child: Center(
                child: Text(
                  '$imagelength',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget buttons({
    required void Function()? onPressed,
    required Widget icon,
    Color? bordercolor,
    Color? backgroundColor,
    Color? shadowColor,
  }) {
    return ButtonTheme(
      height: 40,
      minWidth: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.transparent,
          shadowColor: shadowColor ?? Colors.transparent,
          shape: const CircleBorder(),
          side: BorderSide(color: bordercolor ?? Colors.white, width: 2.0),
          padding: const EdgeInsets.all(10),
        ),
        child: icon,
      ),
    );
  }

  void selectImage() async {
    final List<XFile> selectImage = await imagePicker.pickMultiImage();
    if (selectImage.isEmpty) return;

    if (widget._controller.maxCount != null) {
      final totalLength = widget._controller.files.length + selectImage.length;
      if (totalLength > widget._controller.maxCount!) {
        final errorMessage = widget._controller.maxCountMessage ??
            Utils.translateWithFallback('ensemble.input.maxCountMessage',
                'Maximum ${widget._controller.maxCount} files can be selected');
        if (!mounted) return;
        ToastController().showToast(
            context,
            ShowToastAction(
                type: ToastType.error,
                message: errorMessage,
                alignment: Alignment.topCenter,
                dismissible: true,
                duration: 3),
            null);
        return;
      }
    }

    for (var element in selectImage) {
      final bytes = kIsWeb ? await element.readAsBytes() : null;
      final fileSize = await element.length();
      File file = File(element.name, element.path.split('.').last, fileSize,
          element.path, bytes);
      widget._controller.files.insert(0, file);
    }
    setState(() {});
  }

  void deleteImages() {
    final mediaList = widget._controller.files;
    if (currentIndex >= mediaList.length) currentIndex--;
    mediaList.removeAt(currentIndex);
    final newLength = mediaList.length;
    if (newLength == 0) {
      showPreviewPage = false;
      if (widget._controller.cameraController != null) {
        widget._controller.cameraController!.resumePreview();
      }
    }
    setState(() {});
  }

  String buttonLabel(String label) {
    if (widget._controller.nextButtonLabel != null) {
      return widget._controller.nextButtonLabel!;
    }
    return Utils.translateWithFallback('ensemble.input.nextButtonLabel', label);
  }

  Widget timerWidget(int sec) {
    return Container(
      width: 81,
      height: 35,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.0),
          color: const Color.fromRGBO(20, 20, 20, 0.6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isTimerRunning ? formatDuration(seconds) : '00:00:00',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void startTimer() {
    setState(() {
      isTimerRunning = true;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isRecording) {
        isTimerRunning = false;
        timer.cancel();
      }
      setState(() {
        seconds += 1;
      });
    });
  }

  String formatDuration(int seconds) {
    int hours = (seconds / 3600).floor();
    int minutes = ((seconds % 3600) / 60).floor();
    int remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  Future<File?> stopVideoRecording() async {
    if (!widget._controller.cameraController!.value.isRecordingVideo) {
      return null;
    }

    try {
      XFile file =
          await widget._controller.cameraController!.stopVideoRecording();
      timer = null;
      setState(() {
        isRecording = false;
        seconds = 0;
      });

      final bytes = kIsWeb ? await file.readAsBytes() : null;
      final fileSize = await file.length();
      return File(
          file.name, file.path.split('.').last, fileSize, file.path, bytes);
    } on CameraException catch (_) {
      return null;
    }
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController =
        widget._controller.cameraController;

    if (cameraController!.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.startVideoRecording();
      startTimer();
      setState(() {
        isRecording = true;
      });
    } on CameraException catch (_) {}
  }

  Future<File?> takePicture() async {
    final CameraController? cameraController =
        widget._controller.cameraController;

    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      final bytes = kIsWeb ? await file.readAsBytes() : null;
      final fileSize = await file.length();

      return File(
          file.name, file.path.split('.').last, fileSize, file.path, bytes);
    } on CameraException catch (_) {
      return null;
    }
  }

  void onViewFinderTap(TapUpDetails details, BoxConstraints constraints) {
    final controller = widget._controller.cameraController;
    if (controller == null) return;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );

    _offset = Offset(details.localPosition.dx, details.localPosition.dy);
    _focusState.value = FocusState.success;

    Future.delayed(const Duration(milliseconds: 500), () {
      _focusState.value = FocusState.none;
    });

    controller.setExposurePoint(offset);
    controller.setFocusPoint(offset);
  }

  String getAssistAngleMessage() {
    const defaultAssistAngleMessage =
        'Please raise phone to maintain camera angle.';

    return Utils.translateWithFallback(
      'ensemble.input.overMaxFileSizeMessage',
      widget._controller.assistAngleMessage ?? defaultAssistAngleMessage,
    );
  }

  String getAssistSpeedMessage() {
    const defaultAssistSpeedMessage =
        'Please slow to capture a good quality footage.';

    return Utils.translateWithFallback(
      'ensemble.input.overMaxFileSizeMessage',
      widget._controller.assistSpeedMessage ?? defaultAssistSpeedMessage,
    );
  }
}

enum FocusState {
  none,
  success,
  error,
}

class InlineVideoPlayer extends StatefulWidget {
  const InlineVideoPlayer({super.key, required this.file});

  final File file;

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  late VideoPlayerController playerController;

  @override
  void initState() {
    playerController = kIsWeb
        ? VideoPlayerController.network(widget.file.path!)
        : VideoPlayerController.file(widget.file.toFile()!);
    playerController.initialize();

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    playerController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
        aspectRatio: playerController.value.aspectRatio,
        child: Stack(alignment: Alignment.bottomCenter, children: [
          VideoPlayer(playerController),
          Center(
              child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(.5),
                  radius: 17,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(getVideoIconStatus(playerController)),
                      color: Colors.black54,
                      onPressed: () {
                        setState(() {
                          playerController.value.isPlaying
                              ? playerController.pause()
                              : playerController.play();
                        });
                      })))
        ]));
  }

  IconData getVideoIconStatus(VideoPlayerController playerController) {
    if (playerController.value.isPlaying) {
      return Icons.pause;
    } else if (playerController.value.duration > Duration.zero &&
        playerController.value.duration == playerController.value.position) {
      return Icons.restart_alt;
    }
    return Icons.play_arrow;
  }
}

class DisplayMediaWeb extends StatefulWidget {
  final File file;
  final bool isThumbnail;
  final double? aspectRatio;

  const DisplayMediaWeb(
      {Key? key,
      required this.file,
      this.isThumbnail = false,
      this.aspectRatio})
      : super(key: key);

  @override
  _DisplayMediaWebState createState() => _DisplayMediaWebState();
}

class _DisplayMediaWebState extends State<DisplayMediaWeb> {
  bool _isVideo = false;
  bool _isImage = true;
  bool _loadingError = false;

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  void _initializeMedia() async {
    if (_isImage) {
      final Completer<void> completer = Completer();
      final Image image = Image.network(
        widget.file.path!,
        errorBuilder: (context, error, stackTrace) {
          _loadingError = true;
          return const SizedBox.shrink();
        },
      );
      image.image.resolve(const ImageConfiguration()).addListener(
            ImageStreamListener(
              (info, call) => completer.complete(),
              onError: (error, stackTrace) {
                _loadingError = true;
              },
            ),
          );

      await completer.future.timeout(const Duration(milliseconds: 500),
          onTimeout: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      if (_loadingError) {
        setState(() {
          _isImage = false;
          _isVideo = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      final image = Image.network(
        widget.file.path!,
        fit: widget.isThumbnail ? BoxFit.cover : null,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      );
      return widget.aspectRatio != null
          ? Center(
              child: AspectRatio(
                aspectRatio: widget.aspectRatio!,
                child: image,
              ),
            )
          : image;
    } else if (_isVideo) {
      if (widget.isThumbnail) {
        return const Icon(
          Icons.play_arrow,
          color: Colors.white,
        );
      } else {
        return InlineVideoPlayer(file: widget.file);
      }
    } else {
      return const Text('Failed to load media.');
    }
  }
}
