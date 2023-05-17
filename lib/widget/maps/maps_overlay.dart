import 'package:ensemble/framework/device.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class MapsOverlay extends StatelessWidget {
  const MapsOverlay(this.overlayWidget,
      {super.key, this.scrollable = true, this.onScrolled});
  final Widget overlayWidget;
  final bool scrollable;
  final OverlayScrollCallback? onScrolled;

  @override
  Widget build(BuildContext context) {
    /// Web gives the map all pointer control, so all overlay needs to be
    /// wrapped inside PointerInterceptor.
    var content =
        kIsWeb ? PointerInterceptor(child: overlayWidget) : overlayWidget;

    return Positioned(
        right: 0,
        left: 0,
        bottom: 0,
        child: scrollable && onScrolled != null
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
            : content);
  }
}

typedef OverlayScrollCallback = void Function(bool isNext);
