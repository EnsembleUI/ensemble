import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MapsToolbar extends StatelessWidget {
  const MapsToolbar({super.key, this.onShowLocationButtonCallback});

  final ShowLocationButtonCallback? onShowLocationButtonCallback;

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    if (onShowLocationButtonCallback != null) {
      children.add(
        IconButton(
            onPressed: onShowLocationButtonCallback,
            icon: Image.asset(
              'assets/images/map_location_button.png',
              package: 'ensemble')));
    }

    return Positioned(
        right: 10,
        bottom: 10,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ));
  }

}

typedef ShowLocationButtonCallback = void Function();