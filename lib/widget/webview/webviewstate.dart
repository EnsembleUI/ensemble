library webviewstate;

export 'native/unsupportedwebview.dart'
    if (dart.library.html) 'web/webviewstate.dart'
    if (dart.library.io) 'native/webviewstate.dart';
