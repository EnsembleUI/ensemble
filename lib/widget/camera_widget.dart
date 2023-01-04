import 'dart:io';
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
      'cameraRotateIcon': (value) =>
          _controller.cameraRotateIcon = Utils.getIcon(value),
      'imageTakeIcon': (value) =>
          _controller.imageTakeIcon = Utils.getIcon(value),
      'viewImageIcon': (value) =>
          _controller.viewImageIcon = Utils.getIcon(value),
      'selectImageIcon': (value) =>
          _controller.selectImageIcon = Utils.getIcon(value),
      'rotateIconAlignment': (value) =>
          _controller.rotateIconAlignment = Utils.getAlignment(value),
      'viewIconAlignment': (value) =>
          _controller.viewIconAlignment = Utils.getAlignment(value),
      'captureIconAlignment': (value) =>
          _controller.captureIconAlignment = Utils.getAlignment(value),
      'selectIconAlignment': (value) =>
          _controller.selectIconAlignment = Utils.getAlignment(value),
      'rotateIconPadding': (value) =>
          _controller.rotateIconPadding = Utils.optionalInsets(value),
      'viewIconPadding': (value) =>
          _controller.viewIconPadding = Utils.optionalInsets(value),
      'captureIconPadding': (value) =>
          _controller.captureIconPadding = Utils.optionalInsets(value),
      'selectIconPadding': (value) =>
          _controller.selectIconPadding = Utils.optionalInsets(value),
      'heading': (value) =>
          _controller.heading = Utils.getString(value, fallback: ''),
      'imagesHeight': (value) =>
          _controller.imagesHeight = Utils.optionalDouble(value),
      'imagesWidth': (value) =>
          _controller.imagesWidth = Utils.optionalDouble(value),
      'backgroundColor': (value) =>
          _controller.backgroundColor = Utils.getColor(value),
      'removeImageIcon': (value) =>
          _controller.removeImageIcon = Utils.getIcon(value),
      'alertboxHeight': (value) =>
          _controller.alertboxHeight = Utils.optionalDouble(value),
      'alertboxWidth': (value) =>
          _controller.alertboxWidth = Utils.optionalDouble(value),
      'selectImagesAlignment': (value) =>
          _controller.selectImagesAlignment = Utils.getWrapAlignment(value),
      'selectImagesIconAlignment': (value) =>
          _controller.selectImagesIconAlignment = Utils.getAlignment(value),
      'imagesGap': (value) =>
          _controller.imagesGap = Utils.optionalInsets(value),
    };
  }
}

class MyCameraController extends WidgetController {
  double? height;
  double? width;
  double? imagesHeight;
  double? imagesWidth;
  double? alertboxHeight;
  double? alertboxWidth;

  IconModel? cameraRotateIcon;
  IconModel? imageTakeIcon;
  IconModel? viewImageIcon;
  IconModel? selectImageIcon;
  IconModel? removeImageIcon;

  Alignment? rotateIconAlignment;
  Alignment? viewIconAlignment;
  Alignment? captureIconAlignment;
  Alignment? selectIconAlignment;
  Alignment? selectImagesIconAlignment;
  WrapAlignment? selectImagesAlignment;

  EdgeInsets? rotateIconPadding;
  EdgeInsets? viewIconPadding;
  EdgeInsets? captureIconPadding;
  EdgeInsets? selectIconPadding;
  EdgeInsets? imagesGap;

  String? heading;
  Color? backgroundColor;

  bool isFrontCamera = false;

  List<CameraDescription>? cameras;
  CameraController? cameracontroller;

  final ImagePicker imagePicker = ImagePicker();
  List imageFileList = [];

  Future<void> cameraFunction() async {
    cameras = await availableCameras();
    notifyListeners();
  }

  void initCamera() {
    cameraFunction().then((value) {
      setCamera(0);
    });
  }

  void setCamera(int i) {
    cameracontroller = CameraController(cameras![i], ResolutionPreset.max);
    cameracontroller!.initialize().then((_) {
      notifyListeners();
    });
  }

  void selectImage() async {
    final List<XFile>? selectImage = await imagePicker.pickMultiImage();
    if (selectImage!.isNotEmpty) {
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
    widget._controller.cameraFunction().then((_) {
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
      child: CameraPreview(
        widget._controller.cameracontroller!,
        child: Stack(
          children: [
            widget._controller.cameras!.length > 1
                ? Padding(
                    padding: widget._controller.rotateIconPadding ??
                        const EdgeInsets.only(top: 10.0, right: 10.0),
                    child: Align(
                      alignment: widget._controller.rotateIconAlignment ??
                          Alignment.topRight,
                      child: IconButton(
                        onPressed: () {
                          if (widget._controller.isFrontCamera == false) {
                            widget._controller.setCamera(1);
                            widget._controller.isFrontCamera = true;
                          } else {
                            widget._controller.setCamera(0);
                            widget._controller.isFrontCamera = false;
                          }
                          setState(() {});
                        },
                        icon: widget._controller.cameraRotateIcon != null
                            ? iconframework.Icon.fromModel(
                                widget._controller.cameraRotateIcon!)
                            : const Icon(
                                Icons.rotate_left,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  )
                : const SizedBox(),
            Align(
              alignment:
                  widget._controller.viewIconAlignment ?? Alignment.bottomLeft,
              child: Padding(
                padding: widget._controller.viewIconPadding ??
                    const EdgeInsets.only(right: 10.0, bottom: 10.0),
                child: IconButton(
                  onPressed: () {
                    showImages(context);
                  },
                  icon: widget._controller.viewImageIcon != null
                      ? iconframework.Icon.fromModel(
                          widget._controller.viewImageIcon!)
                      : const Icon(Icons.photo_size_select_actual_outlined,
                          color: Colors.white),
                ),
              ),
            ),
            Align(
              alignment: widget._controller.selectIconAlignment ??
                  Alignment.bottomRight,
              child: Padding(
                padding: widget._controller.selectIconPadding ??
                    const EdgeInsets.only(right: 10.0, bottom: 10.0),
                child: IconButton(
                  onPressed: () {
                    widget._controller.selectImage();
                  },
                  icon: widget._controller.selectImageIcon != null
                      ? iconframework.Icon.fromModel(
                          widget._controller.selectImageIcon!)
                      : const Icon(Icons.photo, color: Colors.white),
                ),
              ),
            ),
            Align(
              alignment: widget._controller.captureIconAlignment ??
                  Alignment.bottomCenter,
              child: Padding(
                padding: widget._controller.captureIconPadding ??
                    const EdgeInsets.only(bottom: 10.0),
                child: IconButton(
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
                  },
                  icon: widget._controller.imageTakeIcon != null
                      ? iconframework.Icon.fromModel(
                          widget._controller.imageTakeIcon!)
                      : const Icon(
                          Icons.circle,
                          color: Colors.white,
                          size: 25.0,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showImages(BuildContext c) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(widget._controller.heading ?? "Images List"),
          content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return SizedBox(
              height: widget._controller.alertboxHeight ??
                  MediaQuery.of(context).size.height,
              width: widget._controller.alertboxWidth ??
                  MediaQuery.of(context).size.width,
              child: Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    alignment: widget._controller.selectImagesAlignment ??
                        WrapAlignment.center,
                    children: widget._controller.imageFileList
                        .map(
                          (i) => Padding(
                            padding: widget._controller.imagesGap ??
                                const EdgeInsets.all(8.0),
                            child: Stack(
                              alignment: widget
                                      ._controller.selectImagesIconAlignment ??
                                  Alignment.topRight,
                              children: [
                                ClipRRect(
                                  child: kIsWeb
                                      ? Image.memory(
                                          i,
                                          fit: BoxFit.cover,
                                          width:
                                              widget._controller.imagesWidth ??
                                                  130.0,
                                          height:
                                              widget._controller.imagesHeight ??
                                                  150.0,
                                        )
                                      : Image.file(
                                          File(i.path),
                                          fit: BoxFit.cover,
                                          width:
                                              widget._controller.imagesWidth ??
                                                  130.0,
                                          height:
                                              widget._controller.imagesHeight ??
                                                  150.0,
                                        ),
                                ),
                                CircleAvatar(
                                  backgroundColor:
                                      widget._controller.backgroundColor ??
                                          Colors.white,
                                  child: Center(
                                    child: IconButton(
                                      icon: widget._controller
                                                  .removeImageIcon !=
                                              null
                                          ? iconframework.Icon.fromModel(widget
                                              ._controller.removeImageIcon!)
                                          : const Icon(
                                              Icons.close,
                                              color: Colors.black,
                                              size: 15.0,
                                            ),
                                      onPressed: () {
                                        widget._controller.imageFileList
                                            .removeWhere(
                                                (element) => element == i);
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
