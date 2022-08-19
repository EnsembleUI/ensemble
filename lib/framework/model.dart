import 'package:flutter/material.dart';

/// misc models

class BackgroundImage {
  BackgroundImage(this.source, {this.fit});
  String source;
  BoxFit? fit;

  bool _isUrl() {
    return source.startsWith('https://') || source.startsWith('http://');
  }

  DecorationImage get image {
    ImageProvider imageProvider;
    if (_isUrl()) {
      imageProvider = NetworkImage(source);
    } else {
      imageProvider = AssetImage('assets/images/$source');
    }
    return DecorationImage(
      image: imageProvider,
      fit: fit ?? BoxFit.cover);
  }

}