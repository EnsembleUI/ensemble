import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/model.dart';
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

  void showToast(BuildContext context, ShowToastAction toastAction,
      Widget? customToastBody) {
    _toast.init(context);
    _toast.removeQueuedCustomToasts();

    ToastGravity toastGravity;
    switch (toastAction.position) {
      case 'top':
        toastGravity = ToastGravity.TOP;
        break;
      case 'topLeft':
        toastGravity = ToastGravity.TOP_LEFT;
        break;
      case 'topRight':
        toastGravity = ToastGravity.TOP_RIGHT;
        break;
      case 'center':
        toastGravity = ToastGravity.CENTER;
        break;
      case 'centerLeft':
        toastGravity = ToastGravity.CENTER_LEFT;
        break;
      case 'centerRight':
        toastGravity = ToastGravity.CENTER_RIGHT;
        break;
      case 'bottom':
        toastGravity = ToastGravity.BOTTOM;
        break;
      case 'bottomLeft':
        toastGravity = ToastGravity.BOTTOM_LEFT;
        break;
      case 'bottomRight':
        toastGravity = ToastGravity.BOTTOM_RIGHT;
        break;
      default:
        toastGravity = ToastGravity.TOP_RIGHT;
        break;
    }

    _toast.showToast(
        gravity: toastGravity,
        toastDuration: toastAction.duration != null
            ? Duration(seconds: toastAction.duration!)
            : const Duration(days: 99),
        child: getToastWidget(toastAction, customToastBody));
  }

  Widget getToastWidget(ShowToastAction toastAction, Widget? customToastBody) {
    EdgeInsets padding = Utils.getInsets(toastAction.styles?['padding'],
        fallback: const EdgeInsets.symmetric(vertical: 20, horizontal: 22));
    Color? bgColor = Utils.getColor(toastAction.styles?['backgroundColor']);
    EBorderRadius? borderRadius =
        Utils.getBorderRadius(toastAction.styles?['borderRadius']);
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
        bgColor ??= Colors.green.withOpacity(.5);
      } else if (toastAction.type == ToastType.error) {
        icon = Icons.error_outline;
        bgColor ??= Colors.red.withOpacity(.5);
      } else if (toastAction.type == ToastType.warning) {
        icon = Icons.warning;
        bgColor ??= Colors.yellow.withOpacity(.5);
      } else {
        // info by default
        icon = Icons.info;
        bgColor ??= Colors.white.withOpacity(.9);
      }

      const double closeButtonRadius = 10;

      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 18),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (toastAction.title != null && toastAction.title!.isNotEmpty)
                Text(toastAction.title!,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              if (toastAction.message != null &&
                  toastAction.message!.isNotEmpty)
                Flexible(
                  child: Text(
                    toastAction.message!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
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
