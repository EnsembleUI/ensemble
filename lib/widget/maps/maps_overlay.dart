import 'package:ensemble/framework/device.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class MapsOverlay extends StatelessWidget {
  const MapsOverlay(this.overlayWidget,
      {super.key,
      this.scrollable = true,
      this.onScrolled,
      this.maxWidth,
      this.maxHeight});
  final Widget overlayWidget;
  final int? maxWidth;
  final int? maxHeight;
  final bool scrollable;
  final OverlayScrollCallback? onScrolled;

  @override
  Widget build(BuildContext context) {
    /// Web gives the map all pointer control, so all overlay needs to be
    /// wrapped inside PointerInterceptor.
    var content =
        kIsWeb ? PointerInterceptor(child: overlayWidget) : overlayWidget;

    var gestureWrapper = scrollable && onScrolled != null
        ? GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < 0) {
                  onScrolled!(true); // next marker
                } else if (details.primaryVelocity! > 0) {
                  onScrolled!(false); // previous marker
                }
              }
            },
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
