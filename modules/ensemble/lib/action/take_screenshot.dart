import 'dart:typed_data';
import 'dart:io';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

class TakeScreenshotAction extends EnsembleAction {
  TakeScreenshotAction({
    super.initiator,
    required this.widgetId,
    this.pixelRatio,
    this.onSuccess,
    this.onFailure,
  });

  final dynamic widgetId;
  final double? pixelRatio;
  final EnsembleAction? onSuccess;
  final EnsembleAction? onFailure;

  factory TakeScreenshotAction.fromYaml({Map? payload}) {
    if (payload == null || payload['widgetId'] == null) {
      throw LanguageError(
          "${ActionType.takeScreenshot.name} requires 'widgetId'");
    }
    return TakeScreenshotAction(
      widgetId: payload['widgetId'],
      pixelRatio: Utils.optionalDouble(payload['options']?['pixelRatio']),
      onSuccess: payload['onSuccess'] != null
          ? EnsembleAction.from(payload['onSuccess'])
          : null,
      onFailure: payload['onFailure'] != null
          ? EnsembleAction.from(payload['onFailure'])
          : null,
    );
  }

  factory TakeScreenshotAction.fromMap(dynamic inputs) =>
      TakeScreenshotAction.fromYaml(payload: Utils.getYamlMap(inputs));

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    final screenshotController = ScreenshotController();

    try {
      final resolvedWidget = scopeManager.dataContext.eval(widgetId);
      if (resolvedWidget == null) {
        throw LanguageError("Widget not found: '$widgetId'");
      }

      final widget = Screenshot(
        controller: screenshotController,
        child: resolvedWidget,
      );

      final Uint8List? capturedImage =
          await screenshotController.captureFromWidget(
        MediaQuery(
          data: MediaQuery.of(context),
          child: Theme(
              data: Theme.of(context),
              child: Material(
                child: widget,
              )),
        ),
        delay: const Duration(milliseconds: 100),
        pixelRatio: pixelRatio ?? MediaQuery.of(context).devicePixelRatio,
        context: context,
      );

      if (capturedImage == null) {
        throw LanguageError("Failed to capture screenshot");
      }

      final filePath = await _saveImageToFile(capturedImage);

      if (onSuccess != null) {
        await ScreenController().executeAction(
          context,
          onSuccess!,
          event: EnsembleEvent(initiator, data: {'filePath': filePath}),
        );
      }
    } catch (e) {
      if (onFailure != null) {
        await ScreenController().executeAction(
          context,
          onFailure!,
          event: EnsembleEvent(initiator, data: {'error': e.toString()}),
        );
      }
      rethrow;
    }
  }

  Future<String> _saveImageToFile(Uint8List imageBytes) async {
    try {
      final directory = Directory('/storage/emulated/0/DCIM/Pictures');
      await directory.create(recursive: true);

      final filePath =
          '${directory.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(filePath).writeAsBytes(imageBytes);

      return filePath;
    } catch (e) {
      throw LanguageError("Failed to save screenshot: $e");
    }
  }
}
