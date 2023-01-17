import 'dart:io';
import 'package:ensemble/widget/widget_util.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:ensemble/framework/widget/icon.dart' as iconframework;
import 'package:camera/camera.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../framework/model.dart';

class Camera extends StatefulWidget
    with Invokable, HasController<MyCameraController, CameraState> {
  static const type = 'Camera';

  Camera({Key? key}) : super(key: key);

  final MyCameraController _controller = MyCameraController();

  @override
  MyCameraController get controller => _controller;

  @override
  State<StatefulWidget> createState() => CameraState();

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
      'height': (value) => _controller.height = Utils.optionalDouble(value),
      'width': (value) => _controller.width = Utils.optionalDouble(value),
      'ImagePreviewHeight': (value) =>
          _controller.ImagePreviewHeight = Utils.optionalDouble(value),
      'ImagePreviewWidth': (value) =>
          _controller.ImagePreviewWidth = Utils.optionalDouble(value),
      'fullImageWidth': (value) =>
          _controller.fullImageWidth = Utils.optionalDouble(value),
      'fullImageHeight': (value) =>
          _controller.fullImageHeight = Utils.optionalDouble(value),
      'cameraRotateIcon': (value) =>
          _controller.cameraRotateIcon = Utils.getIcon(value),
      'selectImageIcon': (value) =>
          _controller.selectImageIcon = Utils.getIcon(value),
      'backIcon': (value) => _controller.backIcon = Utils.getIcon(value),
      'deleteIcon': (value) => _controller.deleteIcon = Utils.getIcon(value),
      'imagesHeight': (value) =>
          _controller.imagesHeight = Utils.optionalDouble(value),
      'imagesWidth': (value) =>
          _controller.imagesWidth = Utils.optionalDouble(value),
      'listHeight': (value) =>
          _controller.listHeight = Utils.optionalDouble(value),
      'listWidth': (value) =>
          _controller.listWidth = Utils.optionalDouble(value),
    };
  }
}

class MyCameraController extends WidgetController {
  double? height;
  double? width;
  double? imagesHeight;
  double? imagesWidth;
  double? listHeight;
  double? listWidth;
  double? fullImageWidth;
  double? fullImageHeight;
  double? ImagePreviewHeight;
  double? ImagePreviewWidth;

  IconModel? cameraRotateIcon;
  IconModel? selectImageIcon;
  IconModel? backIcon;
  IconModel? deleteIcon;

  bool isFrontCamera = false;
  bool imagePreview = false;
  bool isPermission = false;

  var fullImage;

  List<CameraDescription> cameras = [];
  CameraController? cameracontroller;

  final ImagePicker imagePicker = ImagePicker();
  List imageFileList = [];

  SizedBox space = const SizedBox(
    height: 10,
  );

  // this function is user for initialized camera

  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();
      notifyListeners();
    } on CameraException catch (e) {
      // if the camera permission is denied than isPermission is true because change display for user
      if (e.toString().contains('CameraAccessDenied')) {
        isPermission = true;
        notifyListeners();
      }
    }
  }

  // this function is check how much cameras support in the device
  void setCamera(int i) {
    cameracontroller = CameraController(cameras[i], ResolutionPreset.max);
    cameracontroller!.initialize().then((_) {
      notifyListeners();
    });
  }

  // this function is used to pick images from gallery
  void selectImage() async {
    final List<XFile> selectImage = await imagePicker.pickMultiImage();
    if (selectImage.isNotEmpty) {
      if (kIsWeb) {
        for (var element in selectImage) {
          imageFileList.add(await element.readAsBytes());
        }
      } else {
        imageFileList.addAll(selectImage);
      }
      notifyListeners();
    }
  }
}

class CameraState extends WidgetState<Camera> {
  @override
  void initState() {
    widget._controller.initCamera().then((_) {
      widget._controller.setCamera(0);
    });
    super.initState();
  }

  @override
  void dispose() {
    widget._controller.cameracontroller!.dispose();
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    // this condition is run when permission is denied or no camera support in device
    if (widget._controller.isPermission || widget._controller.cameras.isEmpty) {
      return widget._controller.imagePreview
          ? imagePreview()
          : permissionDeniedView();
    }
    // this condition is run when permission is granted and wait for camera initialized
    if (widget._controller.cameracontroller == null ||
        !widget._controller.cameracontroller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    // this condition is run when permission is granted and camera is initialized
    return SizedBox(
      height: widget._controller.height,
      width: widget._controller.width,
      child: widget._controller.imagePreview ? imagePreview() : cameraPreview(),
    );
  }

  // this is permission denied view
  Widget permissionDeniedView() {
    return SizedBox(
      height: widget._controller.height ?? 500,
      width: widget._controller.width ?? 500,
      child: Column(
        children: [
          widget._controller.imageFileList.isNotEmpty
              ? imagePreviewButton()
              : const SizedBox(),
          const Spacer(),
          const Text(
              'To capture photos and videos, allow access to your camera.'),
          textbutton(
              title: 'Allow access',
              onPressed: () {
                widget._controller.selectImage();
              }),
          const Spacer(),
          imagesPreview(),
          textbutton(
              title: 'Pick from gallery',
              onPressed: () {
                widget._controller.selectImage();
              }),
        ],
      ),
    );
  }

  //<------ This is Image Preview --------->
  Widget imagePreview() {
    return Column(
      children: [
        appbar(
          backArrowAction: () {
            if (widget._controller.cameracontroller == null) {
              setState(() {
                widget._controller.imagePreview = false;
              });
            } else {
              setState(() {
                widget._controller.cameracontroller!.resumePreview();
                widget._controller.imagePreview = false;
              });
            }
          },
          deleteButtonAction: () {
            deleteImages();
          },
        ),
        widget._controller.space,
        SizedBox(
          width: widget._controller.ImagePreviewWidth ??
              MediaQuery.of(context).size.width,
          height: widget._controller.ImagePreviewHeight ??
              MediaQuery.of(context).size.height / 1.3,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: widget._controller.fullImageWidth ??
                      MediaQuery.of(context).size.width,
                  height: widget._controller.fullImageHeight ??
                      MediaQuery.of(context).size.height / 1.6,
                  child: kIsWeb
                      ? Image.memory(
                          widget._controller.fullImage,
                          fit: BoxFit.contain,
                        )
                      : Image.file(
                          File(widget._controller.fullImage.path),
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
        widget._controller.space,
        textbutton(
          onPressed: () {},
          title: 'Upload',
        ),
      ],
    );
  }

  //<------ This code is used for delete image and point next image to preview or delete image ---->

  void deleteImages() {
    int i = widget._controller.imageFileList
        .indexWhere((element) => element == widget._controller.fullImage);
    if (i == 0) {
      if (widget._controller.imageFileList.length > 1) {
        setState(() {
          widget._controller.imageFileList.removeWhere(
              (element) => element == widget._controller.fullImage);
        });
        for (int j = 0; j < widget._controller.imageFileList.length; j++) {
          setState(() {
            widget._controller.fullImage = widget._controller.imageFileList[i];
          });
        }
      } else {
        setState(() {
          widget._controller.imageFileList.removeWhere(
              (element) => element == widget._controller.fullImage);
          widget._controller.imagePreview = false;
          if (widget._controller.cameracontroller != null) {
            widget._controller.cameracontroller!.resumePreview();
          }
        });
      }
    } else if (i + 1 == widget._controller.imageFileList.length) {
      if (widget._controller.imageFileList.length > 1) {
        widget._controller.imageFileList
            .removeWhere((element) => element == widget._controller.fullImage);
        for (int j = 0; j < widget._controller.imageFileList.length; j++) {
          setState(() {
            widget._controller.fullImage =
                widget._controller.imageFileList[i - 1];
          });
        }
      } else {
        setState(() {
          widget._controller.imageFileList.removeWhere(
              (element) => element == widget._controller.fullImage);
          widget._controller.imagePreview = false;
          if (widget._controller.cameracontroller != null) {
            widget._controller.cameracontroller!.resumePreview();
          }
        });
      }
    } else {
      widget._controller.imageFileList
          .removeWhere((element) => element == widget._controller.fullImage);
      for (int j = 0; j < widget._controller.imageFileList.length; j++) {
        setState(() {
          widget._controller.fullImage = widget._controller.imageFileList[i];
        });
      }
    }
  }

  //<------ This is Camera Preview --------->
  Widget cameraPreview() {
    return CameraPreview(
      widget._controller.cameracontroller!,
      child: Stack(
        children: [
          Column(
            children: [
              // <----- This Row is Created for Preview Image and show full image and delete image ------>
              widget._controller.imageFileList.isNotEmpty
                  ? imagePreviewButton()
                  : const SizedBox(),
              const Spacer(),
              // <----- This is Created for Image Preview ------>
              imagesPreview(),
              // <----- This is Created for Camera Button ------>
              cameraButton(),
            ],
          ),
        ],
      ),
    );
  }

  // this is a camera button to click image and pick image form gallery and rotate camera
  Widget cameraButton() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // <----- This button is used for pick image in gallery ------>
          buttons(
            icon: widget._controller.selectImageIcon != null
                ? iconframework.Icon.fromModel(
                    widget._controller.selectImageIcon!)
                : const Icon(Icons.photo_size_select_actual_outlined,
                    size: 15.0, color: Colors.white),
            onPressed: () {
              widget._controller.selectImage();
              // showImages(context);
            },
          ),
          const Spacer(),
          // <----- This button is used for take image ------>
          GestureDetector(
            onTap: (){
              widget._controller.cameracontroller!
                  .takePicture()
                  .then((value) async {
                if (kIsWeb) {
                  widget._controller.imageFileList
                      .add(await value.readAsBytes());
                } else {
                  widget._controller.imageFileList.add(value);
                }
                setState(() {});
              });
            },
            child: Container(
              height: 65,
              width: 65,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white,width: 2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  height: 55,
                  width: 55,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          // buttons(
          //     icon: widget._controller.imageTakeIcon != null
          //         ? iconframework.Icon.fromModel(
          //             widget._controller.imageTakeIcon!)
          //         : const Icon(
          //             Icons.circle_outlined,
          //             color: Colors.white,
          //             size: 25.0,
          //           ),
          //     onPressed: () {
          //       widget._controller.cameracontroller!
          //           .takePicture()
          //           .then((value) async {
          //         if (kIsWeb) {
          //           widget._controller.imageFileList
          //               .add(await value.readAsBytes());
          //         } else {
          //           widget._controller.imageFileList.add(value);
          //         }
          //         setState(() {});
          //       });
          //     }),
          const Spacer(),
          // <----- This button is used for rotate camera if camera is exist more than one camera ------>
          buttons(
              icon: widget._controller.cameraRotateIcon != null
                  ? iconframework.Icon.fromModel(
                      widget._controller.cameraRotateIcon!)
                  : const Icon(
                      Icons.flip_camera_ios_outlined,
                      size: 15.0,
                      color: Colors.white,
                    ),
              onPressed: () {
                if (widget._controller.isFrontCamera == false) {
                  widget._controller.setCamera(1);
                  widget._controller.isFrontCamera = true;
                } else {
                  widget._controller.setCamera(0);
                  widget._controller.isFrontCamera = false;
                }
                setState(() {});
              }),
        ],
      ),
    );
  }

  // this is a next button code for preview selected images
  Widget imagePreviewButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: nextButton(
            buttontitle: 'Next',
            imagelength: widget._controller.imageFileList.length.toString(),
            onTap: () {
              if (widget._controller.cameracontroller != null) {
                setState(() {
                  widget._controller.cameracontroller!.pausePreview();
                  widget._controller.imagePreview = true;
                  widget._controller.fullImage =
                      widget._controller.imageFileList[0];
                });
              } else {
                setState(() {
                  widget._controller.imagePreview = true;
                  widget._controller.fullImage =
                      widget._controller.imageFileList[0];
                });
              }
            },
          ),
        ),
      ],
    );
  }

  // <----- This Appbar is created for back image preview to camera and delete image ------>
  Widget appbar(
      {required void Function()? backArrowAction,
      required void Function()? deleteButtonAction}) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, right: 10.0),
      child: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black54,
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: Offset(0, 3))
                ]),
            child: Center(
              child: IconButton(
                onPressed: backArrowAction,
                icon: widget._controller.backIcon != null
                    ? iconframework.Icon.fromModel(widget._controller.backIcon!)
                    : const Icon(Icons.arrow_back),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: deleteButtonAction,
            icon: widget._controller.deleteIcon != null
                ? iconframework.Icon.fromModel(widget._controller.deleteIcon!)
                : const Icon(Icons.delete_sharp),
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

  // <----- This is used for preview images ------>

  Widget imagesPreview({bool isImageOnTap = false, bool isBorderView = false}) {
    return SizedBox(
      height: widget._controller.listHeight ?? 150,
      width: widget._controller.listWidth ?? MediaQuery.of(context).size.width,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: widget._controller.imageFileList.length,
        itemBuilder: (c, i) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                GestureDetector(
                  onTap: isImageOnTap
                      ? () {
                          setState(() {
                            widget._controller.fullImage =
                                widget._controller.imageFileList[i];
                          });
                        }
                      : null,
                  child: ClipRRect(
                    child: Container(
                      width: widget._controller.imagesWidth ?? 150.0,
                      height: widget._controller.imagesHeight ?? 150.0,
                      decoration: BoxDecoration(
                        border: isBorderView
                            ? widget._controller.fullImage ==
                                    widget._controller.imageFileList[i]
                                ? Border.all(color: Colors.indigo , width: 2.0)
                                : null
                            : null,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                      child: kIsWeb
                          ? Image.memory(
                              widget._controller.imageFileList[i],
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(widget._controller.imageFileList[i].path),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // <----- This is used for preview all images ------>

  Widget nextButton(
      {String? buttontitle, String? imagelength, void Function()? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            buttontitle!,
          ),
          const SizedBox(
            width: 5.0,
          ),
          Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                color: Colors.white),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '$imagelength',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // <----- This is used for camera button i make this for common to reused code ------>

  Widget buttons(
      {required void Function()? onPressed,
      required Widget icon,
      Color? bordercolor}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: bordercolor ?? Colors.white, width: 1.5),
        color: Colors.white.withOpacity(0.2),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
      ),
    );
  }
}
