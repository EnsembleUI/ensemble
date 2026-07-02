import 'dart:typed_data';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'saveFile/save_mobile.dart';

/// Ensemble action that captures a widget or screen as an image.
class TakeScreenshotAction extends EnsembleAction {
  /// Creates a [TakeScreenshotAction] action.
  TakeScreenshotAction({
    super.initiator,
    required this.widgetId,
    this.pixelRatio,
    this.onSuccess,
    this.onError,
  });

  /// Widget identifier to capture for screenshots.
  final dynamic widgetId;
  /// Screenshot scale factor used when rendering image bytes.
  final double? pixelRatio;
  /// Action executed when the operation succeeds.
  final EnsembleAction? onSuccess;
  /// Action executed when the operation fails.
  final EnsembleAction? onError;

  /// Creates a [TakeScreenshotAction] from a YAML or map action payload.
  factory TakeScreenshotAction.fromYaml({Map? payload}) {
    if (payload == null || payload['widgetId'] == null) {
      throw LanguageError(
          "${ActionType.takeScreenshot.name} requires 'widgetId'");
    }
    return TakeScreenshotAction(
      widgetId: payload['widgetId'],
      pixelRatio: Utils.optionalDouble(payload['pixelRatio']),
      onSuccess: payload['onSuccess'] != null
          ? EnsembleAction.from(payload['onSuccess'])
          : null,
      onError: payload['onError'] != null
          ? EnsembleAction.from(payload['onError'])
          : null,
    );
  }

  /// Runs this action and captures the configured widget or screen area.
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
        child: DataScopeWidget(
          scopeManager: scopeManager,
          child: resolvedWidget,
        ),
      );

      final Uint8List? capturedImage =
          // It will only capture readonly widgets
          await screenshotController.captureFromLongWidget(
        InheritedTheme.captureAll(
          context,
          Material(
            type: MaterialType.transparency,
            child: widget,
          ),
        ),
        pixelRatio: pixelRatio ?? MediaQuery.of(context).devicePixelRatio,
        context: context,
      );

      if (capturedImage == null) {
        throw LanguageError("Failed to capture screenshot");
      }

      final dimensions = await _getImageDimensions(capturedImage);
      // Save screenshot to gallery and download on web
      await _saveScreenshot(capturedImage);

      if (onSuccess != null) {
        await ScreenController().executeAction(
          context,
          onSuccess!,
          event: EnsembleEvent(initiator, data: {
            'imageBytes': capturedImage, // capturedImage contains Image Bytes
            'size': capturedImage.length,
            'dimensions': dimensions,
          }),
        );
      }
    } catch (e) {
      if (onError != null) {
        await ScreenController().executeAction(
          context,
          onError!,
          event: EnsembleEvent(initiator, data: {'error': e.toString()}),
        );
      }
    }
  }

  Future<void> _saveScreenshot(Uint8List fileBytes) async {
    // Screenshot name of current date
    // Get the current date and time
    DateTime now = DateTime.now();

    // Format the date and time
    String formattedDateTime = DateFormat('yyyyMMdd_HHmmss').format(now);

    // Combine the prefix with the formatted date and time
    String screenshotName = 'screenshot_$formattedDateTime';

    await saveImageToDCIM(screenshotName, fileBytes);
  }

  Future<Map<String, int>> _getImageDimensions(Uint8List imageData) async {
    final image = await decodeImageFromList(imageData);
    return {
      'width': image.width,
      'height': image.height,
    };
  }
}
