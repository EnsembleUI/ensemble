import 'package:ensemble/framework/device.dart';
import 'package:flutter/cupertino.dart';

class MapsOverlay extends StatelessWidget {
  const MapsOverlay(this.overlayWidget,
      {super.key, this.scrollable, this.onScrolled});
  final Widget overlayWidget;
  final bool? scrollable;
  final OverlayScrollCallback? onScrolled;

  @override
  Widget build(BuildContext context) {
    return Positioned(
        bottom: 30,
        left: 30,
        right: 30,
        child: scrollable != false && onScrolled != null
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
