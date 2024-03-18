import 'package:ensemble/framework/model.dart';
import 'package:ensemble_icons/remixicon.dart';
import 'package:ensemble_icons/fontAwesomeIcon.dart';
import 'package:ensemble_icons/materialIcon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;

class Icon extends flutter.Icon {
  Icon(
    dynamic icon, {
    Key? key,
    String? library,
    int? size,
    Color? color,
  }) : super(_iconFromName(icon, library),
            key: key, size: size?.toDouble(), color: color);

  factory Icon.fromModel(IconModel model,
      {Color? fallbackColor, String? fallbackLibrary}) {
    return Icon(model.icon,
        library: model.library ?? fallbackLibrary,
        size: model.size,
        color: model.color ?? fallbackColor);
  }

  static IconData? _iconFromName(dynamic name, String? library) {
    if (library == null ||
        library == 'default' ||
        library.toString().trim().isEmpty) {
      return MaterialIcons.iconMap[name];
    } else if (library == 'fontAwesome') {
      return FontAwesome.iconMap[name];
    } else if (library == 'remix') {
      return Remix.iconMap[name];
    }
    // tree shaking won't work. Need to add --no-tree-shake-icons to ignore error when building
    else if (name is int) {
      // semi-custom font embedded in our source
      if (library == 'idealTalent') {
        return IconData(name, fontFamily: 'packages/ensemble/$library');
      }
      // else assume custom icon fonts, embedded in the custom ensemble_starter repo
      return IconData(name, fontFamily: library);
    }
    return null;
  }
}
