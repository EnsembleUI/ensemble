import 'package:camera/camera.dart';
import 'package:ensemble/framework/widget/camera_manager.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ensemble/framework/widget/icon.dart' as iconframework;
import '../framework/model.dart';
// import 'package:flutter/foundation.dart' show kIsWeb;

class CameraScreen extends StatefulWidget
    with Invokable, HasController<MyCameraController, CameraScreenState> {
  static const type = 'Camera';
  CameraScreen({
    Key? key,
  }) : super(key: key);

  final MyCameraController _controller = MyCameraController();

  @override
  State<StatefulWidget> createState() => CameraScreenState();

  @override
  MyCameraController get controller => _controller;

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
      'mode': (value) => _controller.initCameraMode(value),
      'initialCamera': (value) => _controller.initCameraOption(value),
      'useGallery': (value) => _controller.useGallery =
          Utils.optionalBool(value) ?? _controller.useGallery,
      'maxCount': (value) => _controller.maxCount =
          Utils.optionalInt(value) ?? _controller.maxCount,
      'preview': (value) => _controller.preview =
          Utils.optionalBool(value) ?? _controller.preview,
      'maxCountMessage': (value) =>
          _controller.maxCountMessage = Utils.getString(value, fallback: ''),
      'permissionDeniedMessage': (value) => _controller
          .permissionDeniedMessage = Utils.getString(value, fallback: ''),
      'nextButtonLabel': (value) =>
          _controller.nextButtonLabel = Utils.getString(value, fallback: ''),
      'accessButtonLabel': (value) =>
          _controller.accessButtonLabel = Utils.getString(value, fallback: ''),
      'galleryButtonLabel': (value) =>
          _controller.galleryButtonLabel = Utils.getString(value, fallback: ''),
      'imagePickerIcon': (value) =>
          _controller.imagePickerIcon = Utils.getIcon(value),
      'cameraRotateIcon': (value) =>
          _controller.cameraRotateIcon = Utils.getIcon(value),
    };
  }
}

class MyCameraController extends WidgetController {
  CameraController? cameracontroller;

  CameraMode? mode;
  InitialCamera? initialCamera;
  bool useGallery = true;
  int maxCount = 1;
  bool preview = false;
  String? maxCountMessage;
  String? permissionDeniedMessage;
  String? nextButtonLabel;
  String? accessButtonLabel;
  String? galleryButtonLabel;

  IconModel? imagePickerIcon;
  IconModel? cameraRotateIcon;

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

class CameraScreenState extends WidgetState<CameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> cameras = [];
  late PageController pageController;

  var fullImage;

  final ImagePicker imagePicker = ImagePicker();
  List imageFileList = [];

  bool isFrontCamera = false;
  bool isImagePreview = false;
  bool isRecording = false;
  bool isPermission = false;
  String errorString = '';
  int index = 0;

  List cameraoptionsList = [];

  SizedBox space = const SizedBox(
    height: 10,
  );

  Color iconColor = const Color(0xff0086B8);
  double iconSize = 20.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getMaxSelectedMessage();
    initCamera().then((_) {
      ///initialize camera and choose the back camera as the initial camera in use.
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
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    });
    pageController = PageController(viewportFraction: 0.25, initialPage: index);
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
      cameraoptionsList = ['PHOTO'];
    } else if (widget._controller.mode == CameraMode.video) {
      errorString =
          'Maximum ${widget._controller.maxCount} videos may be selected';
      cameraoptionsList = ['VIDEO'];
    } else {
      errorString =
          'Maximum ${widget._controller.maxCount} images and videos may be selected';
      cameraoptionsList = ['PHOTO', 'VIDEO'];
    }
    setState(() {});
  }

  /// chooses the camera to use, where the front camera has index = 1, and the rear camera has index = 0
  void setCamera(
      {bool isNotDefine = false, CameraDescription? cameraDescription}) {
    // in web case if one camera exist than description is not define that why i added isWeb
    if (isNotDefine) {
      widget._controller.cameracontroller =
          CameraController(cameras[0], ResolutionPreset.max);
      widget._controller.cameracontroller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    } else {
      widget._controller.cameracontroller =
          CameraController(cameraDescription!, ResolutionPreset.max);
      widget._controller.cameracontroller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    widget._controller.cameracontroller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget._controller.cameracontroller!.resumePreview();
      print("State is ${state.toString()}");
    }
    if (state == AppLifecycleState.inactive) {
      widget._controller.cameracontroller!.pausePreview();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (isPermission || cameras.isEmpty) {
      return isImagePreview ? fullImagePreview() : permissionDeniedView();
    }
    if (widget._controller.cameracontroller == null ||
        !widget._controller.cameracontroller!.value.isInitialized) {
      return Container();
    }
    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          if (isImagePreview) {
            if (widget._controller.cameracontroller == null) {
              setState(() {
                isImagePreview = false;
              });
            } else {
              setState(() {
                widget._controller.cameracontroller!.resumePreview();
                isImagePreview = false;
              });
            }
          } else {
            Navigator.pop(context, imageFileList);
          }
          return false;
        },
        child: Scaffold(
          body: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: isImagePreview ? fullImagePreview() : cameraView(),
          ),
        ),
      ),
    );
  }

  Widget cameraView() {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: CameraPreview(
        widget._controller.cameracontroller!,
        child: Column(
          children: [
            imagePreviewButton(),
            const Spacer(),
            // <----- This is Created for Image Preview ------>
            imagesPreview(),
            // <----- This is Created for Camera Button ------>
            cameraButton(),
          ],
        ),
      ),
    );
  }

  //<------ This is Image Preview --------->
  Widget fullImagePreview() {
    return Column(
      children: [
        appbar(
          backArrowAction: () {
            if (widget._controller.cameracontroller == null) {
              setState(() {
                isImagePreview = false;
              });
            } else {
              setState(() {
                widget._controller.cameracontroller!.resumePreview();
                isImagePreview = false;
              });
            }
          },
          deleteButtonAction: () {
            deleteImages();
          },
        ),
        space,
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height / 1.4,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height / 1.7,
                  child: Image.memory(
                    fullImage,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: imagesPreview(
                  isImageOnTap: true,
                  isBorderView: true,
                ),
              )
            ],
          ),
        ),
        space,
        textbutton(
          onPressed: () {
            Navigator.pop(context, imageFileList);
          },
          title: 'Done',
        ),
      ],
    );
  }

  // this is permission denied view
  Widget permissionDeniedView() {
    return SizedBox(
      height: 500,
      width: 500,
      child: Column(
        children: [
          imagePreviewButton(),
          const Spacer(),
          Text(
            widget._controller.permissionDeniedMessage ??
                Utils.translateWithFallback('ensemble.input.maxCountMessage',
                    'To capture photos and videos, allow access to your camera.'),
          ),
          textbutton(
              title: widget._controller.accessButtonLabel ??
                  Utils.translateWithFallback(
                      'ensemble.input.accessButtonLabel', 'Allow access'),
              onPressed: () {
                selectImage();
              }),
          const Spacer(),
          imagesPreview(),
          textbutton(
            title: widget._controller.galleryButtonLabel ??
                Utils.translateWithFallback(
                    'ensemble.input.galleryButtonLabel', 'Pick from gallery'),
            onPressed: () {
              selectImage();
            },
          ),
        ],
      ),
    );
  }

  Widget imagesPreview({bool isImageOnTap = false, bool isBorderView = false}) {
    return SizedBox(
      height: 72,
      width: MediaQuery.of(context).size.width,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: imageFileList.length,
        itemBuilder: (c, i) {
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: GestureDetector(
              onTap: isImageOnTap
                  ? () {
                      setState(() {
                        fullImage = imageFileList[i];
                      });
                    }
                  : null,
              child: Container(
                width: 72.0,
                height: 72.0,
                decoration: BoxDecoration(
                  border: isBorderView
                      ? fullImage == imageFileList[i]
                          ? Border.all(color: iconColor, width: 3.0)
                          : Border.all(color: Colors.transparent, width: 3.0)
                      : Border.all(color: Colors.transparent, width: 3.0),
                  borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(isBorderView
                      ? const Radius.circular(0.0)
                      : const Radius.circular(5.0)),
                  child: Image.memory(
                    imageFileList[i],
                    fit: BoxFit.cover,
                  ),
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
        children: [
          buttons(
              onPressed: backArrowAction,
              icon: Icon(
                Icons.arrow_back,
                color: Colors.black,
                size: iconSize,
              ),
              backgroundColor: Colors.white,
              shadowColor: Colors.black54),
          const Spacer(),
          IconButton(
            onPressed: deleteButtonAction,
            icon: Icon(
              Icons.delete_sharp,
              color: iconColor,
              size: iconSize,
            ),
          )
        ],
      ),
    );
  }

  // <----- This Button is used for upload images to sever or firebase ------>
  Widget textbutton(
      {required void Function()? onPressed, required String title}) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        title,
      ),
    );
  }

  // this is a camera button to click image and pick image form gallery and rotate camera
  Widget cameraButton() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            silderView(),
            space,
            Row(
              children: [
                // <----- This button is used for pick image in gallery ------>
                widget._controller.useGallery
                    ? buttons(
                        icon: widget._controller.imagePickerIcon != null
                            ? iconframework.Icon.fromModel(
                                widget._controller.imagePickerIcon!)
                            : Icon(Icons.photo_size_select_actual_outlined,
                                size: iconSize, color: iconColor),
                        backgroundColor: Colors.white.withOpacity(0.3),
                        onPressed: () {
                          selectImage();
                          // showImages(context);
                        },
                      )
                    : const SizedBox(
                        width: 60,
                      ),
                const Spacer(),
                // <----- This button is used for take image ------>
                GestureDetector(
                  onTap: () async {
                    if (imageFileList.length >= widget._controller.maxCount) {
                      FlutterToast.showToast(
                        title: widget._controller.maxCountMessage ??
                            Utils.translateWithFallback(
                                'ensemble.input.maxCountMessage', errorString),
                      );
                    } else {
                      if (index == 1) {
                        if (isRecording) {
                          await widget._controller.cameracontroller!
                              .stopVideoRecording();
                          setState(() {
                            isRecording = false;
                          });
                        } else {
                          try {
                            await widget._controller.cameracontroller!
                                .prepareForVideoRecording();
                            await widget._controller.cameracontroller!
                                .startVideoRecording();
                            setState(() {
                              isRecording = true;
                            });
                          } catch (e) {
                            print("Check Recording Error ${e.toString()}");
                          }
                        }
                      } else {
                        widget._controller.cameracontroller!
                            .takePicture()
                            .then((value) async {
                          imageFileList.add(await value.readAsBytes());
                          if (widget._controller.maxCount == 1) {
                            Navigator.pop(context, imageFileList);
                          }
                          setState(() {});
                        });
                      }
                    }
                  },
                  child: Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        height: isRecording ? 25 : 46,
                        width: isRecording ? 25 : 46,
                        decoration: BoxDecoration(
                          color: index == 1
                              ? const Color(0xffFF453A)
                              : Colors.white.withOpacity(0.5),
                          // shape: isRecording? BoxShape.rectangle : BoxShape.circle,
                          borderRadius: BorderRadius.all(isRecording
                              ? const Radius.circular(5)
                              : const Radius.circular(30)),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // <----- This button is used for rotate camera if camera is exist more than one camera ------>
                cameras.length == 1
                    ? const SizedBox(
                        width: 60,
                      )
                    : buttons(
                        icon: widget._controller.cameraRotateIcon != null
                            ? iconframework.Icon.fromModel(
                                widget._controller.cameraRotateIcon!)
                            : Icon(
                                Icons.flip_camera_ios_outlined,
                                size: iconSize,
                                color: iconColor,
                              ),
                        backgroundColor: Colors.white.withOpacity(0.3),
                        onPressed: () {
                          index = 0;
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
        onPageChanged: (i) {
          setState(() {
            index = i;
          });
        },
        itemCount: cameraoptionsList.length,
        itemBuilder: ((c, i) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: i == index ? 1 : 0.5,
            child: Center(
              child: Text(
                cameraoptionsList[i].toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Roboto',
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black,
                    )
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // this is a next button code for preview selected images
  Widget imagePreviewButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          buttons(
            icon: Icon(Icons.close, size: iconSize, color: iconColor),
            backgroundColor: Colors.white.withOpacity(0.3),
            onPressed: () {
              Navigator.pop(context, imageFileList);
            },
          ),
          const Spacer(),
          imageFileList.isNotEmpty
              ? nextButton(
                  buttontitle: widget._controller.preview
                      ? buttonLable('Next')
                      : buttonLable('Done'),
                  imagelength: imageFileList.length.toString(),
                  onTap: () {
                    if (widget._controller.preview) {
                      if (widget._controller.cameracontroller != null) {
                        setState(() {
                          widget._controller.cameracontroller!.pausePreview();
                          isImagePreview = true;
                          fullImage = imageFileList[0];
                        });
                      } else {
                        setState(() {
                          isImagePreview = true;
                          fullImage = imageFileList[0];
                        });
                      }
                    } else {
                      Navigator.pop(context, imageFileList);
                    }
                  },
                )
              : const SizedBox(),
        ],
      ),
    );
  }

  // <----- This is used for preview all images ------>

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
                  fontSize: 17.0,
                  fontFamily: 'Roboto',
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

  // <----- This is used for camera button i make this for common to reused code ------>

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

  // this function is used to pick images from gallery
  void selectImage() async {
    final List<XFile> selectImage = await imagePicker.pickMultiImage();
    if (imageFileList.length >= widget._controller.maxCount) {
      FlutterToast.showToast(
          title: widget._controller.maxCountMessage ??
              Utils.translateWithFallback(
                  'ensemble.input.maxCountMessage', errorString));
      return;
    } else {
      if (selectImage.length > widget._controller.maxCount) {
        FlutterToast.showToast(
            title: widget._controller.maxCountMessage ??
                Utils.translateWithFallback(
                    'ensemble.input.maxCountMessage', errorString));
        return;
      } else {
        if (selectImage.isNotEmpty) {
          for (var element in selectImage) {
            imageFileList.add(await element.readAsBytes());
            if (widget._controller.maxCount == 1) {
              Navigator.pop(context, imageFileList);
            }
          }
          setState(() {});
        }
      }
    }
  }

  //<------ This code is used for delete image and point next image to preview or delete image ---->

  void deleteImages() {
    int i = imageFileList.indexWhere((element) => element == fullImage);
    if (i == 0) {
      if (imageFileList.length > 1) {
        setState(() {
          imageFileList.removeWhere((element) => element == fullImage);
        });
        for (int j = 0; j < imageFileList.length; j++) {
          setState(() {
            fullImage = imageFileList[i];
          });
        }
      } else {
        setState(() {
          imageFileList.removeWhere((element) => element == fullImage);
          isImagePreview = false;
          if (widget._controller.cameracontroller != null) {
            widget._controller.cameracontroller!.resumePreview();
          }
        });
      }
    } else if (i + 1 == imageFileList.length) {
      if (imageFileList.length > 1) {
        imageFileList.removeWhere((element) => element == fullImage);
        for (int j = 0; j < imageFileList.length; j++) {
          setState(() {
            fullImage = imageFileList[i - 1];
          });
        }
      } else {
        setState(() {
          imageFileList.removeWhere((element) => element == fullImage);
          isImagePreview = false;
          if (widget._controller.cameracontroller != null) {
            widget._controller.cameracontroller!.resumePreview();
          }
        });
      }
    } else {
      imageFileList.removeWhere((element) => element == fullImage);
      for (int j = 0; j < imageFileList.length; j++) {
        setState(() {
          fullImage = imageFileList[i];
        });
      }
    }
  }

  String buttonLable(String label) {
    if (widget._controller.nextButtonLabel != null) {
      return widget._controller.nextButtonLabel!;
    }
    return Utils.translateWithFallback('ensemble.input.nextButtonLabel', label);
  }
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
