
import 'package:flutter/material.dart';

class EnsembleIcon extends Icon {
  EnsembleIcon(
      String icon,
      {
        Key? key,
        String? library,
        int? size,
      }) : super(_iconFromName(icon, library), key: key, size: size?.toDouble());

  static IconData? _iconFromName(String name, String? library) {
    return _defaultIcons[name];
  }

  /// Flutter icons
  static final Map<String, IconData> _defaultIcons = {
    'lock': Icons.lock,
    'email': Icons.email,
  };

  /// FontAwesome icons
  static final Map<String, IconData> _fontAwesomeIcons = {

  };


}