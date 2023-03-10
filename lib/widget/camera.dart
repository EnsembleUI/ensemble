import 'dart:async';

import 'package:camera/camera.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/camera_manager.dart';
import 'package:ensemble/framework/widget/icon.dart' as iconframework;
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../framework/action.dart';
import '../framework/model.dart';
import '../screen_controller.dart';

class Camera extends StatefulWidget
    with Invokable, HasController<MyCameraController, CameraState> {
  static const type = 'Camera';
  Camera({
    Key? key,
  }) : super(key: key);

  final MyCameraController _controller = MyCameraController();

  @override
  State<StatefulWidget> createState() => CameraState();

  @override
  MyCameraController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {
      'mediaList': () => _controller.mediaList.map((e) => e.toJson()).toList()
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'mode': (value) => _controller.initCameraMode(value),
      'initialCamera': (value) => _controller.initCameraOption(value),
      'useGallery': (value) => _controller.useGallery =
          Utils.optionalBool(value) ?? _controller.useGallery,
      'maxCount': (value) => _controller.maxCount =
          Utils.optionalInt(value) ?? _controller.maxCount,
      'preview': (value) => _controller.preview =
          Utils.optionalBool(value) ?? _controller.preview,
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
      'onComplete': (value) =>
          _controller.onComplete = Utils.getAction(value, initiator: this),
    };
  }
}

class MyCameraController extends WidgetController {
  CameraController? cameraController;

  CameraMode? mode;
  InitialCamera? initialCamera;
  bool useGallery = true;
  int? maxCount;
  bool preview = false;
  String? maxCountMessage;
  String? permissionDeniedMessage;
  String? nextButtonLabel;
  String? accessButtonLabel;
  String? galleryButtonLabel;

  IconModel? imagePickerIcon;
  IconModel? cameraRotateIcon;
  EnsembleAction? onComplete;

  List<File> mediaList = [];

  void initCameraOption(dynamic data) {
    if (data != null) {
      initialCamera = data;
      notifyListeners();
    } else {
      initialCamera = InitialCamera.back;
      notifyListeners();
    }
  }

  void initCameraMode(dynamic data) {
    if (data != null) {
      mode = data;
      notifyListeners();
    } else {
      mode = CameraMode.both;
      notifyListeners();
    }
  }
}

class CameraState extends WidgetState<Camera>
    with WidgetsBindingObserver {
  final ImagePicker imagePicker = ImagePicker();
  List<CameraDescription> cameras = [];
  late PageController pageController;
  File? currentFile;

  bool isFrontCamera = false;
  bool isImagePreview = false;
  bool isRecording = false;
  bool isPermission = false;
  bool isLoading = false;
  String errorString = '';
  int currentModeIndex = 0;

  List<CameraMode> modes = [];

  late Color iconColor = Theme.of(context).colorScheme.primary;
  double iconSize = 24.0;

  int seconds = 0;
  bool isTimerRunning = false;
  Timer? timer;

  bool _isVideoCameraSelected = false;
  FocusState _focusState = FocusState.none;
  Offset? _offset;
  
  bool isFullScreen = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getMaxSelectedMessage();
    initCamera().then((_) {
      ///initialize camera and choose the back camera as the initial camera in use.
      setCameraInit();
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            break;
          default:
            break;
        }
      }
    });
    setCameraMode();
    pageController = PageController(viewportFraction: 0.25, initialPage: currentModeIndex);
    setState(() {});
  }

  Future initCamera() async {
    cameras = await availableCameras();
    setState(() {});
  }

  void getMaxSelectedMessage() {
    if (widget._controller.mode == CameraMode.photo) {
      errorString =
          'Maximum ${widget._controller.maxCount} images may be selected';
    } else if (widget._controller.mode == CameraMode.video) {
      errorString =
          'Maximum ${widget._controller.maxCount} videos may be selected';
    } else {
      errorString =
          'Maximum ${widget._controller.maxCount} images and videos may be selected';
    }
    setState(() {});
  }

  /// chooses the camera to use, 
  /// where the front camera has `index` = 1, 
  /// and the rear camera has `index` = 0
  void setCamera(
      {bool isNotDefine = false, CameraDescription? cameraDescription}) {
    // in web case if one camera exist than description is not define that why i added isWeb
    if (isNotDefine) {
      widget._controller.cameraController =
          CameraController(cameras[0], ResolutionPreset.max);
      widget._controller.cameraController!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    } else {
      widget._controller.cameraController =
          CameraController(cameraDescription!, ResolutionPreset.max);
      widget._controller.cameraController!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    }
  }

  void setCameraInit() {
    if (cameras.length >= 2) {
      if (widget._controller.initialCamera == InitialCamera.back) {
        final back = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back);
        setCamera(cameraDescription: back);
      } else if (widget._controller.initialCamera == InitialCamera.front) {
        final front = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front);
        setCamera(cameraDescription: front);
        isFrontCamera = true;
        setState(() {});
      }
    } else {
      setCamera(isNotDefine: true);
    }
  }

  void setCameraMode() {
    if (widget._controller.mode == CameraMode.both) {
      modes.addAll([CameraMode.photo, CameraMode.video]);
    } else if (widget._controller.mode == CameraMode.video) {
      modes.add(CameraMode.video);
    } else {
      modes.add(CameraMode.photo);
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget._controller.cameraController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = widget._controller.cameraController;

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
    if (isPermission || cameras.isEmpty) {
      return isImagePreview ? fullImagePreview() : permissionDeniedView();
    }
    if (widget._controller.cameraController == null ||
        !widget._controller.cameraController!.value.isInitialized) {
      return Container();
    }
    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          if (isImagePreview) {
            if (widget._controller.cameraController == null) {
              setState(() {
                isImagePreview = false;
              });
            } else {
              setState(() {
                widget._controller.cameraController!.resumePreview();
                isImagePreview = false;
              });
            }
          } else {
            Navigator.pop(context, widget._controller.mediaList);
          }
          return false;
        },
        child: Scaffold(
          body: isImagePreview ? fullImagePreview() : cameraView(),
        ),
      ),
    );
  }

  Widget cameraView() {
    return Stack(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: CameraPreview(
            widget._controller.cameraController!,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: (details) => onViewFinderTap(details, constraints),
                  onScaleUpdate: (details) async {
                    final _zoom = details.scale.clamp(1.0, 2.0);
                    widget._controller.cameraController?.setZoomLevel(_zoom);
                  },
                );
              }
            ),
          ),
        ),
        imagePreviewButton(),
        Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget._controller.mediaList.isEmpty ? const SizedBox.shrink():  mediaThumbnail(),
              cameraButton(),
            ],
          )
        ),
        if (_focusState == FocusState.success)
          Positioned(
            left: _offset!.dx - 24,
            top: _offset!.dy - 24,
            child: Icon(Icons.filter_tilt_shift, color: iconColor, size: 48),
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
            Center(
              child: ['mp4'].contains(currentFile?.path?.split('.').last) 
                    ? InlineVideoPlayer(file: currentFile!,)
                    : Image.file(currentFile!.toFile()!),
            ),
            isFullScreen ? appbar(
              backArrowAction: () {
                if (widget._controller.cameraController != null) {
                  widget._controller.cameraController!.resumePreview();
                } 
                setState(() {
                  isImagePreview = false;
                });
              },
              deleteButtonAction: deleteImages,
            ) : const SizedBox.shrink(),
            isFullScreen ? Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      mediaThumbnail(isBorderView: true),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (widget._controller.onComplete != null) {
                            ScreenController().executeAction(
                                context, widget._controller.onComplete!,
                                event: EnsembleEvent(widget));
                          } 
                          Navigator.pop(context, widget._controller.mediaList);
                        },
                        child: const Text('Done'),
                      ),
                    ],
                ),
              ),
            ) : const SizedBox.shrink(),
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
                Utils.translateWithFallback('ensemble.input.maxCountMessage',
                    'To capture photos and videos, allow access to your camera.'),
          ),
          ElevatedButton(
              child: Text(widget._controller.accessButtonLabel ??
                  Utils.translateWithFallback(
                      'ensemble.input.accessButtonLabel', 'Allow access')),
              onPressed: handlPermission,
          ),
          const Spacer(),
          mediaThumbnail(),
          ElevatedButton(
            child: Text(widget._controller.galleryButtonLabel ??
                Utils.translateWithFallback(
                    'ensemble.input.galleryButtonLabel', 'Pick from gallery')),
            onPressed: selectImage,
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
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: widget._controller.mediaList.length,
        itemBuilder: (context, index) {
          final reverseIndex = widget._controller.mediaList.length - index - 1;
          final file = widget._controller.mediaList[reverseIndex];
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  currentFile = file;
                  isImagePreview = true;
                });
              },
              child: Container(
                width: 72.0,
                height: 82.0,
                decoration: BoxDecoration(
                  color:
                      file.path?.split('.').contains('mp4') ?? false
                          ? Colors.black.withOpacity(0.3)
                          : Colors.transparent,
                  border: isBorderView
                      ? currentFile!.path ==
                              widget._controller.mediaList[reverseIndex].path
                          ? Border.all(color: iconColor, width: 3.0)
                          : Border.all(color: Colors.transparent, width: 3.0)
                      : Border.all(color: Colors.transparent, width: 3.0),
                  borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                ),
                child: ClipRRect(
                    borderRadius: BorderRadius.all(isBorderView
                        ? const Radius.circular(0.0)
                        : const Radius.circular(5.0)),
                    child: file.path?.split('.').contains('mp4') ?? false
                      ?  const Icon(
                        Icons.play_arrow,
                        color: Colors.black54,
                      )
                      : Image.file(file.toFile()!, fit: BoxFit.cover)
                    ),
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
              color: Colors.black,
              size: iconSize,
            ),
            backgroundColor: Colors.white,
            shadowColor: Colors.black54
          ),
          buttons(
            onPressed: deleteButtonAction,
            icon: Icon(
              Icons.delete_sharp,
              color: iconColor,
              size: iconSize,
            ),
            backgroundColor: Colors.white,
            shadowColor: Colors.black54
          ),
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
            silderView(),
            const SizedBox(height: 12,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                widget._controller.useGallery
                    ? buttons(
                        icon: widget._controller.imagePickerIcon != null
                            ? iconframework.Icon.fromModel(
                                widget._controller.imagePickerIcon!)
                            : Icon(Icons.photo_size_select_actual_outlined,
                                size: iconSize, color: iconColor),
                        backgroundColor: Colors.white.withOpacity(0.1),
                        onPressed: selectImage,
                      )
                    : const SizedBox(width: 60),
              InkWell(
                  onTap: modes[currentModeIndex] == CameraMode.video
                      ? () async {
                          if (isRecording) {
                            XFile? rawVideo = await stopVideoRecording();
                            if (rawVideo == null) return;
                            final bytes = kIsWeb ? await rawVideo.readAsBytes() : null;
                            final fileSize = await rawVideo.length();
                            File videoFile = File(rawVideo.name,rawVideo.path.split('.').last,fileSize,  rawVideo.path, bytes );

                            widget._controller.mediaList.add(videoFile);

                          } else {
                            await startVideoRecording();
                          }
                        }
                      : () async {
                          XFile? rawImage = await takePicture();
                          if (rawImage == null) return;
                            final bytes = kIsWeb ? await rawImage.readAsBytes() : null;
                            final fileSize = await rawImage.length();
                            File imageFile = File(rawImage.name,rawImage.path.split('.').last,fileSize,  rawImage.path, bytes );

                          widget._controller.mediaList.add(imageFile);
                          setState(() {});
                        },
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
                        color: _isVideoCameraSelected
                            ? Colors.red
                            : Colors.white,
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
                
                buttons(
                    icon: widget._controller.cameraRotateIcon != null
                        ? iconframework.Icon.fromModel(
                            widget._controller.cameraRotateIcon!)
                        : Icon(
                            Icons.flip_camera_ios_outlined,
                            size: iconSize,
                            color: iconColor,
                          ),
                    backgroundColor: Colors.white.withOpacity(0.1),
                    onPressed: () {
                      currentModeIndex = 0;

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
                      setState(() {});
                    }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget silderView() {
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
            opacity: index == currentModeIndex || widget._controller.mode == CameraMode.video
                ? 1
                : 0.5,
            child: Center(
              child: InkWell(
                onTap: () {
                  if (isRecording) return;
                  _isVideoCameraSelected = modes.elementAt(index) == CameraMode.video;
                  setState(() {
                    currentModeIndex = index;
                  });
                  pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
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
              widget._controller.mediaList.clear();
              Navigator.pop(context, widget._controller.mediaList);
            },
          ),
          
          isRecording ? timerWidget(seconds) : const SizedBox(),
          
          widget._controller.mediaList.isNotEmpty
              ? nextButton(
                  buttontitle: widget._controller.preview
                      ? buttonLabel('Next')
                      : buttonLabel('Done'),
                  imagelength:
                      widget._controller.mediaList.length.toString(),
                  onTap: () {
                    if (widget._controller.preview) {
                      if (widget._controller.cameraController != null) {
                        widget._controller.cameraController!.pausePreview();
                      } 
                        setState(() {
                          isImagePreview = true;
                          currentFile = widget._controller.mediaList[widget._controller.mediaList.length - 1 ];
                        });
                    } else {
                      Navigator.pop(context, widget._controller.mediaList);
                    }
                  },
                )
              : const SizedBox(
                  width: 30.0,
                ),
        ],
      ),
    );
  }

  Widget nextButton(
      {String? buttontitle, String? imagelength, void Function()? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 35,
        width: 93,
        decoration: BoxDecoration(
            color: const Color.fromRGBO(20, 20, 20, 0.6),
            borderRadius: BorderRadius.circular(24.0)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              buttontitle!,
              style: TextStyle(
                  color: isPermission ? Colors.black : Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600),
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
        child: icon,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.transparent,
          shadowColor: shadowColor ?? Colors.transparent,
          shape: const CircleBorder(),
          side: BorderSide(color: bordercolor ?? Colors.white, width: 2.0),
          padding: const EdgeInsets.all(10),
        ),
      ),
    );
  }

  void selectImage() async {
    final List<XFile> selectImage = await imagePicker.pickMultiImage();

    if (selectImage.isEmpty) return;
    for (var element in selectImage) {
      final bytes = kIsWeb ? await element.readAsBytes() : null;
      final fileSize = await element.length();
      File file = File(element.name,element.path.split('.').last, fileSize,  element.path, bytes );
      widget._controller.mediaList.add(file);
    }
    setState(() {});
    // TODO max file 
  }
  
  void deleteImages() {
    // TODO
    int i = widget._controller.mediaList
        .indexWhere((element) => element.path == currentFile?.path);
    if (i == 0) {
      if (widget._controller.mediaList.length > 1) {
        setState(() {
          widget._controller.mediaList
              .removeWhere((element) => element.path == currentFile?.path);
        });
        for (int j = 0; j < widget._controller.mediaList.length; j++) {
          setState(() {
            currentFile = widget._controller.mediaList[i];
          });
        }
      } else {
        setState(() {
          widget._controller.mediaList
              .removeWhere((element) => element.path == currentFile?.path);
          isImagePreview = false;
          if (widget._controller.cameraController != null) {
            widget._controller.cameraController!.resumePreview();
          }
        });
      }
    } else if (i + 1 == widget._controller.mediaList.length) {
      if (widget._controller.mediaList.length > 1) {
        widget._controller.mediaList
            .removeWhere((element) => element.path == currentFile?.path);
        for (int j = 0; j < widget._controller.mediaList.length; j++) {
          setState(() {
            currentFile = widget._controller.mediaList[i - 1];
          });
        }
      } else {
        setState(() {
          widget._controller.mediaList
              .removeWhere((element) => element.path == currentFile?.path);
          isImagePreview = false;
          if (widget._controller.cameraController != null) {
            widget._controller.cameraController!.resumePreview();
          }
        });
      }
    } else {
      widget._controller.mediaList
          .removeWhere((element) => element.path == currentFile?.path);
      for (int j = 0; j < widget._controller.mediaList.length; j++) {
        setState(() {
          currentFile = widget._controller.mediaList[i];
        });
      }
    }
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

  Future<XFile?> stopVideoRecording() async {
    if (!widget._controller.cameraController!.value.isRecordingVideo) {
      return null;
    }

    try {
      XFile file = await widget._controller.cameraController!.stopVideoRecording();
      timer = null;
      setState(() {
        isRecording = false;
        seconds = 0;
      });
      return file;
    } on CameraException catch (_) {
      return null;
    }
  }
  
  Future<void> startVideoRecording() async {
    final CameraController? cameraController = widget._controller.cameraController;

    if (cameraController!.value.isRecordingVideo) {
      return;
    }

    try {
      await cameraController.startVideoRecording();
      startTimer();
      setState(() {
        isRecording = true;
      });
    } on CameraException catch (e) {
      print('Error starting to record video: $e');
    }
  }
  
  Future<XFile?> takePicture() async {
    final CameraController? cameraController = widget._controller.cameraController;

    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      print('Error occured while taking picture: $e');
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

    setState(() {
      _focusState = FocusState.success;
      _offset = Offset(details.localPosition.dx,details.localPosition.dy);
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _focusState = FocusState.none;
      });
    });

    controller.setExposurePoint(offset);
    controller.setFocusPoint(offset);


  }

  void handlPermission() {
    // TODO
  }
}

enum FocusState {
  none,
  success,
  error,
}

class FlutterToast {
  static void showToast({
    required String title,
  }) {
    Fluttertoast.showToast(
      msg: title,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
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

    playerController =  kIsWeb ? VideoPlayerController.network(widget.file.path!) : VideoPlayerController.file(widget.file.toFile()!);
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
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
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
                    playerController.value.isPlaying ? playerController.pause() : playerController.play();
                  });
                }
              )
            )
          )
        ]
      )
    );
  }

  IconData getVideoIconStatus(VideoPlayerController playerController) {
    if (playerController.value.isPlaying) {
      return Icons.pause;
    } else if (playerController.value.duration > Duration.zero && playerController.value.duration == playerController.value.position) {
      return Icons.restart_alt;
    }
    return Icons.play_arrow;
  }

}


