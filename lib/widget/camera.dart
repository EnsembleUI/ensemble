import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {

  List<CameraDescription> cameras = [];

  CameraController? cameracontroller;

  var fullImage;

  final ImagePicker imagePicker = ImagePicker();
  List imageFileList = [];

  bool isFrontCamera = false;
  bool isImagePreview = false;
  bool isPermission = false;

  SizedBox space = const SizedBox(
    height: 10,
  );

  @override
  void initState() {
    super.initState();
    initCamera().then((_) {
      ///initialize camera and choose the back camera as the initial camera in use.
      setCamera(0);
    });
  }

  Future initCamera() async {
    cameras = await availableCameras();
    setState(() {});
  }

  /// chooses the camera to use, where the front camera has index = 1, and the rear camera has index = 0
  void setCamera(int index) {
    cameracontroller = CameraController(cameras[index], ResolutionPreset.max);
    cameracontroller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    cameracontroller?.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (isPermission || cameras.isEmpty) {
      return isImagePreview
          ? fullImagePreview()
          : permissionDeniedView();
    }
    if (cameracontroller == null || !cameracontroller!.value.isInitialized) {
      return Container();
    }
    return SafeArea(
      child: Scaffold(
        body: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: isImagePreview ? fullImagePreview() : cameraView(),
        ),
      ),
    );
  }

  Widget cameraView()
  {
    return CameraPreview(
      cameracontroller!,
      child: Column(
        children: [
          imageFileList.isNotEmpty
              ? imagePreviewButton()
              : const SizedBox(),
          const Spacer(),
          // <----- This is Created for Image Preview ------>
          imagesPreview(),
          // <----- This is Created for Camera Button ------>
          cameraButton(),
        ],
      ),
    );
  }

  //<------ This is Image Preview --------->
  Widget fullImagePreview() {
    return Column(
      children: [
        appbar(
          backArrowAction: () {
            if (cameracontroller == null) {
              setState(() {
                isImagePreview = false;
              });
            } else {
              setState(() {
                cameracontroller!.resumePreview();
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
          height: MediaQuery.of(context).size.height / 1.3,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height / 1.6,
                  child: kIsWeb
                      ? Image.memory(
                    fullImage,
                    fit: BoxFit.contain,
                  )
                      : Image.file(
                    File(fullImage.path),
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
          onPressed: () {},
          title: 'Upload',
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
          imageFileList.isNotEmpty
              ? imagePreviewButton()
              : const SizedBox(),
          const Spacer(),
          const Text(
              'To capture photos and videos, allow access to your camera.'),
          textbutton(
              title: 'Allow access',
              onPressed: () {
                selectImage();
              }),
          const Spacer(),
          imagesPreview(),
          textbutton(
              title: 'Pick from gallery',
              onPressed: () {
                selectImage();
              }),
        ],
      ),
    );
  }

  Widget imagesPreview({bool isImageOnTap = false, bool isBorderView = false}) {
    return SizedBox(
      height: 150,
      width: MediaQuery.of(context).size.width,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: imageFileList.length,
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
                      fullImage =
                      imageFileList[i];
                    });
                  }
                      : null,
                  child: ClipRRect(
                    child: Container(
                      width: 150.0,
                      height: 150.0,
                      decoration: BoxDecoration(
                        border: isBorderView
                            ? fullImage ==
                            imageFileList[i]
                            ? Border.all(color: Colors.indigo , width: 2.0)
                            : null
                            : null,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                      child: kIsWeb
                          ? Image.memory(
                        imageFileList[i],
                        fit: BoxFit.cover,
                      )
                          : Image.file(
                        File(imageFileList[i].path),
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
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: deleteButtonAction,
            icon: const Icon(Icons.delete_sharp),
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
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // <----- This button is used for pick image in gallery ------>
          buttons(
            icon: const Icon(Icons.photo_size_select_actual_outlined,
                size: 15.0, color: Colors.white),
            onPressed: () {
              selectImage();
              // showImages(context);
            },
          ),
          const Spacer(),
          // <----- This button is used for take image ------>
          GestureDetector(
            onTap: (){
              cameracontroller!
                  .takePicture()
                  .then((value) async {
                if (kIsWeb) {
                  setState(() async {
                    imageFileList
                        .add(await value.readAsBytes());
                  });
                } else {
                  setState(() {
                    imageFileList.add(value);
                  });
                }
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
          const Spacer(),
          // <----- This button is used for rotate camera if camera is exist more than one camera ------>
          buttons(
              icon: const Icon(
                Icons.flip_camera_ios_outlined,
                size: 15.0,
                color: Colors.white,
              ),
              onPressed: () {
                if (isFrontCamera == false) {
                  setCamera(1);
                  isFrontCamera = true;
                } else {
                  setCamera(0);
                  isFrontCamera = false;
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
            imagelength: imageFileList.length.toString(),
            onTap: () {
              if (cameracontroller != null) {
                setState(() {
                  cameracontroller!.pausePreview();
                  isImagePreview = true;
                  fullImage = imageFileList[0];
                });
              } else {
                setState(() {
                  isImagePreview = true;
                  fullImage = imageFileList[0];
                });
              }
            },
          ),
        ),
      ],
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
      setState(() {});
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
          if (cameracontroller != null) {
            cameracontroller!.resumePreview();
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
          if (cameracontroller != null) {
            cameracontroller!.resumePreview();
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
}

