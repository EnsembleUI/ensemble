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
      'ImagePreviewheight': (value) =>
          _controller.ImagePreviewheight = Utils.optionalDouble(value),
      'ImagePreviewwidth': (value) =>
          _controller.ImagePreviewwidth = Utils.optionalDouble(value),
      'fullImageWidth': (value) =>
          _controller.fullImageWidth = Utils.optionalDouble(value),
      'fullImageheight': (value) =>
          _controller.fullImageheight = Utils.optionalDouble(value),
      'cameraRotateIcon': (value) =>
          _controller.cameraRotateIcon = Utils.getIcon(value),
      'imageTakeIcon': (value) =>
          _controller.imageTakeIcon = Utils.getIcon(value),
      'selectImageIcon': (value) =>
          _controller.selectImageIcon = Utils.getIcon(value),
      'backIcon': (value) => _controller.backIcon = Utils.getIcon(value),
      'deleteIcon': (value) => _controller.deleteIcon = Utils.getIcon(value),
      'rotateIconAlignment': (value) =>
          _controller.rotateIconAlignment = Utils.getAlignment(value),
      'rotateIconPadding': (value) =>
          _controller.rotateIconPadding = Utils.optionalInsets(value),
      'camerasIconAlignment': (value) =>
          _controller.camerasIconAlignment = Utils.getAlignment(value),
      'iconSidesPadding': (value) =>
          _controller.iconSidesPadding = Utils.optionalInsets(value),
      'appbarPadding': (value) =>
          _controller.appbarPadding = Utils.optionalInsets(value),
      'nextBtnPadding': (value) =>
          _controller.nextBtnPadding = Utils.optionalInsets(value),
      'cameraBtnPadding': (value) =>
          _controller.cameraBtnPadding = Utils.optionalInsets(value),
      'heading': (value) =>
          _controller.heading = Utils.getString(value, fallback: ''),
      'imagesHeight': (value) =>
          _controller.imagesHeight = Utils.optionalDouble(value),
      'imagesWidth': (value) =>
          _controller.imagesWidth = Utils.optionalDouble(value),
      'backgroundColor': (value) =>
          _controller.backgroundColor = Utils.getColor(value),
      'backBtnbgColor': (value) =>
          _controller.backBtnbgColor = Utils.getColor(value),
      'backBtnShadowColor': (value) =>
          _controller.backBtnShadowColor = Utils.getColor(value),
      'cameraIconBgColor': (value) =>
          _controller.cameraIconBgColor = Utils.getColor(value),
      'listHeight': (value) =>
          _controller.listHeight = Utils.optionalDouble(value),
      'listWidth': (value) =>
          _controller.listWidth = Utils.optionalDouble(value),
      'selectImagesAlignment': (value) =>
          _controller.selectImagesAlignment = Utils.getWrapAlignment(value),
      'selectImagesIconAlignment': (value) =>
          _controller.selectImagesIconAlignment = Utils.getAlignment(value),
      'fullImagesAlignment': (value) =>
          _controller.fullImagesAlignment = Utils.getAlignment(value),
      'previewImagesListAlignment': (value) =>
          _controller.previewImagesListAlignment = Utils.getAlignment(value),
      'imagesGap': (value) =>
          _controller.imagesGap = Utils.optionalInsets(value),
      'textbuttontitle': (value) =>
          _controller.textbuttontitle = Utils.getString(value, fallback: ''),
      'uploadBtntitle': (value) =>
          _controller.uploadBtntitle = Utils.getString(value, fallback: ''),
      'nextBtntitle': (value) =>
          _controller.nextBtntitle = Utils.getString(value, fallback: ''),
      'shadowOffset': (value) =>
          _controller.shadowOffset = Utils.getOffset(value),
      'shadowblurRadius': (value) =>
          _controller.shadowblurRadius = Utils.optionalDouble(value),
      'shadowSpreadRadius': (value) =>
          _controller.shadowSpreadRadius = Utils.optionalDouble(value),
      'cameraiconBoxShape': (value) =>
          _controller.cameraiconBoxShape = WidgetUtils.getBoxShape(value),
      'backbtnBoxShape': (value) =>
          _controller.backbtnBoxShape = WidgetUtils.getBoxShape(value)
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
  double? fullImageheight;
  double? ImagePreviewheight;
  double? ImagePreviewwidth;

  IconModel? cameraRotateIcon;
  IconModel? imageTakeIcon;
  IconModel? selectImageIcon;
  IconModel? backIcon;
  IconModel? deleteIcon;

  Alignment? rotateIconAlignment;
  Alignment? camerasIconAlignment;
  Alignment? selectImagesIconAlignment;
  Alignment? fullImagesAlignment;
  Alignment? previewImagesListAlignment;
  WrapAlignment? selectImagesAlignment;

  EdgeInsets? rotateIconPadding;
  EdgeInsets? iconSidesPadding;
  EdgeInsets? imagesGap;
  EdgeInsets? appbarPadding;
  EdgeInsets? nextBtnPadding;
  EdgeInsets? cameraBtnPadding;

  String? heading;
  String? textbuttontitle;
  String? uploadBtntitle;
  String? nextBtntitle;
  Color? backgroundColor;
  Color? backBtnbgColor;
  Color? backBtnShadowColor;
  Color? cameraIconBgColor;

  Offset? shadowOffset;
  double? shadowblurRadius;
  double? shadowSpreadRadius;

  BoxShape? cameraiconBoxShape;
  BoxShape? backbtnBoxShape;

  bool isFrontCamera = false;
  bool imagePreview = false;
  var fullImage;

  List<CameraDescription>? cameras;
  CameraController? cameracontroller;

  final ImagePicker imagePicker = ImagePicker();
  List imageFileList = [];

  Future<void> initCamera() async {
    cameras = await availableCameras();
    notifyListeners();
  }

  void setCamera(int i) {
    cameracontroller = CameraController(cameras![i], ResolutionPreset.max);
    cameracontroller!.initialize().then((_) {
      notifyListeners();
    });
  }

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
    if (widget._controller.cameracontroller == null ||
        !widget._controller.cameracontroller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: widget._controller.height,
      width: widget._controller.width,
      child: widget._controller.imagePreview ? imagePreview() : cameraPreview(),
    );
  }

  //<------ This is Image Preview --------->

  Widget imagePreview() {
    return Column(
      children: [
        appbar(
          backArrowAction: () {
            setState(() {
              widget._controller.cameracontroller!.resumePreview();
              widget._controller.imagePreview = false;
            });
          },
          deleteButtonAction: () {
            deleteImages();
          },
        ),
        const SizedBox(
          height: 10.0,
        ),
        SizedBox(
          width: widget._controller.ImagePreviewwidth ??
              MediaQuery.of(context).size.width,
          height: widget._controller.ImagePreviewheight ??
              MediaQuery.of(context).size.height / 1.3,
          child: Stack(
            children: [
              Align(
                alignment: widget._controller.fullImagesAlignment ??
                    Alignment.topCenter,
                child: SizedBox(
                  width: widget._controller.fullImageWidth ??
                      MediaQuery.of(context).size.width,
                  height: widget._controller.fullImageheight ??
                      MediaQuery.of(context).size.height / 1.5,
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
                alignment: widget._controller.previewImagesListAlignment ??
                    Alignment.bottomLeft,
                child: imagesPreview(
                  isImageOnTap: true,
                  isBorderView: true,
                ),
              )
            ],
          ),
        ),
        const SizedBox(
          height: 10.0,
        ),
        textbutton(
          onPressed: () {},
          title: widget._controller.uploadBtntitle ?? 'Upload',
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
          widget._controller.cameracontroller!.resumePreview();
          widget._controller.imagePreview = false;
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
          widget._controller.cameracontroller!.resumePreview();
          widget._controller.imagePreview = false;
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
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: widget._controller.nextBtnPadding ??
                              const EdgeInsets.all(8.0),
                          child: nextButton(
                            buttontitle:
                                widget._controller.nextBtntitle ?? 'Next',
                            imagelength: widget._controller.imageFileList.length
                                .toString(),
                            onTap: () {
                              setState(() {
                                widget._controller.cameracontroller!
                                    .pausePreview();
                                widget._controller.imagePreview = true;
                                widget._controller.fullImage =
                                    widget._controller.imageFileList[0];
                              });
                            },
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(),
              const Spacer(),
              // <----- This is Created for Image Preview ------>
              imagesPreview(),

              // <----- This is Created for Camera Button ------>

              Padding(
                padding: widget._controller.cameraBtnPadding ??
                    const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    // <----- This button is used for pick image in gallery ------>
                    buttons(
                        icon: widget._controller.selectImageIcon != null
                            ? iconframework.Icon.fromModel(
                                widget._controller.selectImageIcon!)
                            : const Icon(
                                Icons.photo_size_select_actual_outlined,
                                size: 15.0,
                                color: Colors.white),
                        onPressed: () {
                          widget._controller.selectImage();
                          // showImages(context);
                        }),
                    const Spacer(),
                    // <----- This button is used for take image ------>
                    buttons(
                        icon: widget._controller.imageTakeIcon != null
                            ? iconframework.Icon.fromModel(
                                widget._controller.imageTakeIcon!)
                            : const Icon(
                                Icons.circle_outlined,
                                color: Colors.white,
                                size: 25.0,
                              ),
                        onPressed: () {
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
                        }),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  // <----- This Appbar is created for back image preview to camera and delete image ------>

  Widget appbar(
      {required void Function()? backArrowAction,
      required void Function()? deleteButtonAction}) {
    return Padding(
      padding: widget._controller.appbarPadding ??
          const EdgeInsets.only(left: 10.0, right: 10.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                color: widget._controller.backBtnbgColor ?? Colors.white,
                shape: widget._controller.backbtnBoxShape ?? BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: widget._controller.backBtnShadowColor ??
                          Colors.black54,
                      spreadRadius: widget._controller.shadowSpreadRadius ?? 5,
                      blurRadius: widget._controller.shadowblurRadius ?? 7,
                      offset:
                          widget._controller.shadowOffset ?? const Offset(0, 3))
                ]),
            child: Center(
              child: IconButton(
                onPressed: backArrowAction,
                icon: widget._controller.backIcon != null
                    ? iconframework.Icon.fromModel(
                        widget._controller.backIcon!)
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
            padding: widget._controller.imagesGap ?? const EdgeInsets.all(8.0),
            child: Stack(
              alignment: widget._controller.selectImagesIconAlignment ??
                  Alignment.topRight,
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
                                ? Border.all(color: Colors.indigo)
                                : null
                            : null,
                      ),
                      child: kIsWeb
                          ? Image.memory(
                              widget._controller.imageFileList[i],
                              fit: BoxFit.contain,
                            )
                          : Image.file(
                              File(widget._controller.imageFileList[i].path),
                              fit: BoxFit.contain,
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
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

  Widget buttons({required void Function()? onPressed, required Widget icon}) {
    return Container(
      decoration: BoxDecoration(
        shape: widget._controller.cameraiconBoxShape ?? BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        color: widget._controller.cameraIconBgColor ??
            Colors.white.withOpacity(0.2),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
      ),
    );
  }
}
