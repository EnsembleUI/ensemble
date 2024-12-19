import 'package:ensemble/action/toast_actions.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme/default_theme.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/ensemble_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// managing Toast dialogs
class ToastController {
  static final FToast _toast = FToast();

  // Singleton
  static final ToastController _instance = ToastController._internal();

  ToastController._internal() {
    //_toast.init(Utils.globalAppKey.currentContext!);
  }

  factory ToastController() {
    return _instance;
  }

  void closeToast() {
    _toast.removeQueuedCustomToasts();
  }

  void showToast(BuildContext context, ShowToastAction toastAction,
      Widget? customToastBody,
      {DataContext? dataContext}) {
    _toast.init(context);
    _toast.removeQueuedCustomToasts();

    ToastGravity toastGravity;
    if (toastAction.alignment == Alignment.topCenter) {
      toastGravity = ToastGravity.TOP;
    } else if (toastAction.alignment == Alignment.topLeft) {
      toastGravity = ToastGravity.TOP_LEFT;
    } else if (toastAction.alignment == Alignment.center) {
      toastGravity = ToastGravity.CENTER;
    } else if (toastAction.alignment == Alignment.centerLeft) {
      toastGravity = ToastGravity.CENTER_LEFT;
    } else if (toastAction.alignment == Alignment.centerRight) {
      toastGravity = ToastGravity.CENTER_RIGHT;
    } else if (toastAction.alignment == Alignment.bottomCenter) {
      toastGravity = ToastGravity.BOTTOM;
    } else if (toastAction.alignment == Alignment.bottomLeft) {
      toastGravity = ToastGravity.BOTTOM_LEFT;
    } else if (toastAction.alignment == Alignment.bottomRight) {
      toastGravity = ToastGravity.BOTTOM_RIGHT;
    } else {
      // default
      toastGravity = ToastGravity.TOP_RIGHT;
    }
    _toast.showToast(
      positionedToastBuilder: (context, child, gravity) {
        return _getPostionWidgetBasedOnGravity(context, child, toastGravity);
      },
      toastDuration: toastAction.duration != null
          ? Duration(seconds: toastAction.duration!)
          : const Duration(seconds: 10),
      child: Align(
        alignment: toastAction.alignment ?? Alignment.center,
        child:
            _getToastWidget(context, dataContext, toastAction, customToastBody),
      ),
    );
  }

  Widget _getPostionWidgetBasedOnGravity(
      BuildContext context, Widget child, ToastGravity? gravity) {
    switch (gravity) {
      case ToastGravity.TOP:
        return Positioned(top: 100.0, left: 24.0, right: 24.0, child: child);
      case ToastGravity.TOP_LEFT:
        return Positioned(top: 100.0, left: 24.0, right: 0.0, child: child);
      case ToastGravity.TOP_RIGHT:
        return Positioned(top: 100.0, right: 24.0, left: 0.0, child: child);
      case ToastGravity.CENTER:
        return Positioned(
            top: 50.0, bottom: 50.0, left: 24.0, right: 24.0, child: child);
      case ToastGravity.CENTER_LEFT:
        return Positioned(
            top: 50.0, bottom: 50.0, left: 24.0, right: 0.0, child: child);
      case ToastGravity.CENTER_RIGHT:
        return Positioned(
            top: 50.0, bottom: 50.0, right: 24.0, left: 0.0, child: child);
      case ToastGravity.BOTTOM_LEFT:
        return Positioned(bottom: 50.0, left: 24.0, right: 0.0, child: child);
      case ToastGravity.BOTTOM_RIGHT:
        return Positioned(bottom: 50.0, right: 24.0, left: 0.0, child: child);
      case ToastGravity.BOTTOM:
      default:
        return Positioned(bottom: 50.0, left: 24.0, right: 24.0, child: child);
    }
  }

  Widget _getToastWidget(BuildContext context, DataContext? dataContext,
      ShowToastAction toastAction, Widget? customToastBody) {
    EdgeInsets padding = Utils.getInsets(toastAction.styles?['padding'],
        fallback: const EdgeInsets.symmetric(vertical: 20, horizontal: 22));
    Color? bgColor = Utils.getColor(toastAction.styles?['backgroundColor']);
    EBorderRadius? borderRadius =
        Utils.getBorderRadius(toastAction.styles?['borderRadius']);
    BoxShadow? boxShadow = Utils.getBoxShadow(toastAction.styles?['boxShadow']);
    Color? shadowColor = Utils.getColor(toastAction.styles?['shadowColor']);
    double? shadowRadius =
        Utils.optionalDouble(toastAction.styles?['shadowRadius'], min: 0);
    Offset? shadowOffset = Utils.getOffset(toastAction.styles?['shadowOffset']);

    Widget? content = customToastBody;
    if (content == null) {
      if (toastAction.title == null && toastAction.message == null) {
        throw LanguageError(
            "${ActionType.showToast.name} requires either a title/message or a valid widget to render.");
      }
      // render the message as the body
      IconData icon;
      if (toastAction.type == ToastType.success) {
        icon = Icons.check_circle_outline;
        bgColor ??= DesignSystem.successBackgroundColor;
      } else if (toastAction.type == ToastType.error) {
        icon = Icons.error_outline;
        bgColor ??= DesignSystem.errorBackgroundColor;
      } else if (toastAction.type == ToastType.warning) {
        icon = Icons.warning;
        bgColor ??= DesignSystem.warningBackgroundColor;
      } else {
        // info by default
        icon = Icons.info;
        bgColor ??= Colors.white.withOpacity(.9);
      }

      const double closeButtonRadius = 10;

      dataContext ??= DataScopeWidget.getScope(context)?.dataContext;
      String? message =
          dataContext?.eval(toastAction.message) ?? toastAction.message;

      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon),
          const SizedBox(width: 18),
          if (message != null && message.isNotEmpty)
            Flexible(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (toastAction.dismissible != false)
            InkWell(
              child: const CircleAvatar(
                backgroundColor: Colors.transparent,
                radius: closeButtonRadius,
                child: Icon(Icons.close, size: closeButtonRadius * 2 - 2),
              ),
              onTap: () => _toast.removeQueuedCustomToasts(),
            )
        ],
      );
    }

    // wrapper container for background/border...
    Widget container = Container(
        padding: padding,
        decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius?.getValue() ??
                const BorderRadius.all(Radius.circular(8)),
            boxShadow: <BoxShadow>[
              boxShadow ??
                  BoxShadow(
                    blurStyle: BlurStyle.outer,
                    color: shadowColor ?? Colors.black26,
                    blurRadius: shadowRadius ?? 3,
                    offset: shadowOffset ?? const Offset(0, 0),
                  )
            ]),
        child: content);

    return container;
  }
}
