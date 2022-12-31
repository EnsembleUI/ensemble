import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
      'height': (value) => controller.height = Utils.optionalDouble(value),
      'width': (value) => controller.width = Utils.optionalDouble(value)
    };
  }
}

class MyCameraController extends WidgetController {
  double? height;
  double? width;

  bool isFrontCamera = false;

  List<CameraDescription>? cameras;
  CameraController? cameracontroller;

  final ImagePicker imagePicker = ImagePicker();
  List<XFile> imageFileList = [];
  List<Uint8List> imagesFileWeb = [];

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
          imagesFileWeb.add(await element.readAsBytes());
        }
      } else {
        imageFileList.addAll(selectImage);
      }

      notifyListeners();
    }
  }

  void seleteImageFromCamera() async {
    final pickFile = await imagePicker.pickImage(source: ImageSource.camera);
    if (pickFile != null) {
      imageFileList.add(pickFile);
      notifyListeners();
    }
  }

  void seleteImageFromGallery() async {
    final pickFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickFile != null) {
      imageFileList.add(pickFile);
      notifyListeners();
    }
  }
}

class CameraState extends WidgetState<Camera> {
  @override
  void initState() {
    widget._controller.cameraFunction().then((_) {
      ///initialize camera and choose the back camera as the initial camera in use.
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
    return kIsWeb ? forWebView() : forMobile();
  }

  Widget forWebView() {
    return Column(
      children: [
        Row(
          children: [
            ElevatedButton(
              child: const Text('Select Multiple Image'),
              onPressed: () {
                widget._controller.selectImage();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding:
                const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                textStyle: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(
              width: 10.0,
            ),
            SizedBox(
              height: 400,
              width: MediaQuery.of(context).size.width / 2,
              child: Stack(
                children: [
                  SizedBox(
                    height: 400,
                    width: MediaQuery.of(context).size.width / 2,
                    child: CameraPreview(widget._controller.cameracontroller!),
                  ),
                  widget._controller.cameras!.isEmpty
                      ? Padding(
                    padding:
                    const EdgeInsets.only(top: 10.0, right: 10.0),
                    child: Align(
                      alignment: Alignment.topRight,
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
                        icon: const Icon(
                          Icons.rotate_left,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                      : const SizedBox(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: IconButton(
                        onPressed: () {
                          widget._controller.cameracontroller!
                              .takePicture()
                              .then((value) async {
                            if (kIsWeb) {
                              widget._controller.imagesFileWeb
                                  .add(await value.readAsBytes());
                            } else {
                              widget._controller.imageFileList.add(value);
                            }
                            setState(() {});
                          });
                          print(
                              'Check Length ${widget._controller.imageFileList.length}');
                        },
                        icon: const Icon(
                          Icons.camera,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
        const SizedBox(
          height: 10.0,
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kIsWeb
                ? widget._controller.imagesFileWeb.length
                : widget._controller.imageFileList.length,
            shrinkWrap: true,
            separatorBuilder: (c, w) {
              return const SizedBox(
                width: 10.0,
              );
            },
            itemBuilder: (c, i) {
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.memory(
                      widget._controller.imagesFileWeb[i],
                      fit: BoxFit.cover,
                      width: 130.0,
                      height: 150.0,
                    )
                        : Image.file(
                      File(widget._controller.imageFileList[i].path),
                      fit: BoxFit.cover,
                      width: 130.0,
                      height: 150.0,
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Center(
                      child: IconButton(
                        alignment: Alignment.center,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.black,
                          size: 15.0,
                        ),
                        onPressed: () {
                          if (kIsWeb) {
                            widget._controller.imagesFileWeb.removeAt(i);
                          } else {
                            widget._controller.imageFileList.removeAt(i);
                          }
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget forMobile() {
    return Column(
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kIsWeb
                ? widget._controller.imagesFileWeb.length
                : widget._controller.imageFileList.length,
            shrinkWrap: true,
            separatorBuilder: (c, w) {
              return const SizedBox(
                width: 10.0,
              );
            },
            itemBuilder: (c, i) {
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.memory(
                      widget._controller.imagesFileWeb[i],
                      fit: BoxFit.cover,
                      width: 130.0,
                      height: 150.0,
                    )
                        : Image.file(
                      File(widget._controller.imageFileList[i].path),
                      fit: BoxFit.cover,
                      width: 130.0,
                      height: 150.0,
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Center(
                      child: IconButton(
                        alignment: Alignment.center,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.black,
                          size: 15.0,
                        ),
                        onPressed: () {
                          if (kIsWeb) {
                            widget._controller.imagesFileWeb.removeAt(i);
                          } else {
                            widget._controller.imageFileList.removeAt(i);
                          }
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(
          height: 10.0,
        ),
        SizedBox(
          height: 400,
          width: MediaQuery.of(context).size.width,
          child: Stack(
            children: [
              SizedBox(
                height: 400,
                width: MediaQuery.of(context).size.width,
                child: CameraPreview(widget._controller.cameracontroller!),
              ),
              widget._controller.cameras!.isEmpty
                  ? Padding(
                padding:
                const EdgeInsets.only(top: 10.0, right: 10.0),
                child: Align(
                  alignment: Alignment.topRight,
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
                    icon: const Icon(
                      Icons.rotate_left,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
                  : const SizedBox(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: IconButton(
                    onPressed: () {
                      widget._controller.cameracontroller!
                          .takePicture()
                          .then((value) async {
                        if (kIsWeb) {
                          widget._controller.imagesFileWeb
                              .add(await value.readAsBytes());
                        } else {
                          widget._controller.imageFileList.add(value);
                        }
                        setState(() {});
                      });
                      print(
                          'Check Length ${widget._controller.imageFileList.length}');
                    },
                    icon: const Icon(
                      Icons.camera,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20.0, bottom: 20.0),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    onPressed: () {
                      widget._controller.selectImage();
                    },
                    icon: const Icon(
                      Icons.image,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
