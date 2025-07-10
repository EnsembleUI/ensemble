import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:json_annotation/json_annotation.dart';

class KeyConverter implements JsonConverter<Uint8List?, String?> {
  const KeyConverter();

  @override
  Uint8List? fromJson(String? json) {
    if (json == null) {
      return null;
    }

    return Uint8List.fromList(hex.decode(json));
  }

  @override
  String? toJson(Uint8List? key) {
    if (key == null) {
      return null;
    }

    return hex.encode(key);
  }
}
