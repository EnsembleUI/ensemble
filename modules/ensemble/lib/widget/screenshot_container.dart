import 'dart:typed_data';
import 'dart:io';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

class ScreenshotContainer extends StatefulWidget
    with
        Invokable,
        HasController<ScreenshotContainerController, ScreenshotContainerState> {
  static const type = 'ScreenshotContainer';

  ScreenshotContainer({Key? key}) : super(key: key);

  final ScreenshotContainerController _controller =
      ScreenshotContainerController();

  @override
  ScreenshotContainerController get controller => _controller;

  ScreenshotContainerState? _state;

  @override
  ScreenshotContainerState? get state => _state;

  set state(covariant ScreenshotContainerState? state) {
    _state = state;
  }

  @override
  State<StatefulWidget> createState() => ScreenshotContainerState();

  @override
  Map<String, Function> getters() {
    return {
      'id': () => _controller.id,
      'widget': () => _controller.widget,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'capture': () async {
        try {
          // Ensure state is not null
          final Uint8List? image = await state?.captureScreenshot();
          // state?.saveImageToDisk(image, 'screenshot.png');
          print(image);
          if (image != null) {
            // Success payload
            Map<String, dynamic> successPayload = {
              'image': image,
              'success': true,
            };

            // Execute onCapture action
            if (_controller.onCapture != null) {
              await ScreenController().executeAction(
                state!.context,
                _controller.onCapture!,
                event: EnsembleEvent(this, data: successPayload),
              );
            }
          }
          return image;
        } catch (e) {
          print('Error capturing screenshot: $e');

          // Error payload
          Map<String, dynamic> errorPayload = {
            'success': false,
            'error': e.toString(),
          };

          if (_controller.onCapture != null) {
            await ScreenController().executeAction(
              state!.context,
              _controller.onCapture!,
              event: EnsembleEvent(this, data: errorPayload),
            );
          }
        }
        return null;
      },
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'id': (value) => _controller.id = Utils.optionalString(value),
      'widget': (widget) => _controller.widget = widget,
      'onCapture': (funcDefinition) => _controller.onCapture =
          EnsembleAction.from(funcDefinition, initiator: this),
    };
  }
}

class ScreenshotContainerController extends BoxController {
  String? _id;
  dynamic _widget;
  EnsembleAction? onCapture;

  String? get id => _id;
  set id(String? value) {
    _id = value;
    notifyListeners();
  }

  dynamic get widget => _widget;
  set widget(dynamic value) {
    _widget = value;
    notifyListeners();
  }
}

class ScreenshotContainerState extends EWidgetState<ScreenshotContainer> {
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    widget.state = this; // Properly link state to the widget
  }

  @override
  Widget buildWidget(BuildContext context) {
    // If no widget is provided, return an empty container
    if (widget._controller.widget == null) {
      return Container();
    }

    // Build the child widget
    Widget childWidget = scopeManager != null
        ? scopeManager!.buildWidgetFromDefinition(widget._controller.widget)
        : Container();

    // Wrap the child widget with Screenshot widget
    Widget screenshotWidget = Screenshot(
      controller: _screenshotController,
      child: childWidget,
    );

    // Wrap with BoxWrapper for standard box properties
    return BoxWrapper(
      widget: screenshotWidget,
      boxController: widget._controller,
    );
  }

  /// Save Uint8List to a file
  // Future<String> saveImageToDisk(Uint8List? imageBytes, String fileName) async {
  //   try {
  //     // Get the current working directory
  //     final String directoryPath = Directory.current.path;

  //     // Define the full path where the image will be saved
  //     final String filePath = 'D:/Ensemble/ABHI/fileName.png';

  //     // Write the image bytes to the file
  //     final File file = File(filePath);
  //     await file.writeAsBytes(imageBytes as List<int>);

  //     print('Image saved at: $filePath');
  //     return filePath; // Return the saved file path
  //   } catch (e) {
  //     print('Error saving image: $e');
  //     rethrow;
  //   }
  // }

  Future<Uint8List?> captureScreenshot() async {
    try {
      await Future.delayed(Duration(milliseconds: 100)); // Optional delay
      final Uint8List? image = await _screenshotController.capture();
      // return Image.memory(
      //   image?.buffer.asUint8List() ?? Uint8List(0),
      //   fit: BoxFit.contain,
      // );
      return image;
    } catch (e) {
      print('Error capturing screenshot: $e');
      return null;
    }
  }
}
