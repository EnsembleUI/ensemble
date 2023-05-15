import 'package:ensemble/framework/device.dart';
import 'package:flutter/cupertino.dart';

class MapsOverlay extends StatelessWidget {
  const MapsOverlay(this.overlayWidget,
      {super.key, this.scrollable = true, this.onScrolled});
  final Widget overlayWidget;
  final bool scrollable;
  final OverlayScrollCallback? onScrolled;

  @override
  Widget build(BuildContext context) {
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
                child: overlayWidget)
            : overlayWidget);
  }
}

typedef OverlayScrollCallback = void Function(bool isNext);
