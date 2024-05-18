import 'package:ensemble/framework/device.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class MapsOverlay extends StatelessWidget {
  const MapsOverlay(this.overlayWidget,
      {super.key,
      this.onScrolled,
      this.onDismissed,
      this.maxWidth,
      this.maxHeight});
  final Widget overlayWidget;
  final int? maxWidth;
  final int? maxHeight;
  final OverlayScrollCallback? onScrolled;
  final OverlayDismissCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    /// Web gives the map all pointer control, so all overlay needs to be
    /// wrapped inside PointerInterceptor.
    var content =
        kIsWeb ? PointerInterceptor(child: overlayWidget) : overlayWidget;

    var gestureWrapper = onDismissed != null || onScrolled != null
        ? GestureDetector(
            onHorizontalDragEnd: onScrolled != null
                ? (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! < 0) {
                        onScrolled!(true); // next marker
                      } else if (details.primaryVelocity! > 0) {
                        onScrolled!(false); // previous marker
                      }
                    }
                  }
                : null,
            onVerticalDragEnd: onDismissed != null
                ? (details) {
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! > 0) {
                      onDismissed!();
                    }
                  }
                : null,
            child: content)
        : content;

    return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: maxWidth?.toDouble() ?? 500,
                maxHeight: maxHeight?.toDouble() ?? Device().screenHeight / 2),
            // always stretch the content, up to the constraints
            child: SizedBox(
              width: double.infinity,
              child: gestureWrapper,
            )));
  }
}

typedef OverlayScrollCallback = void Function(bool isNext);
typedef OverlayDismissCallback = void Function();
