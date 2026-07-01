export 'src/unsupported.dart'
    if (dart.library.html) 'src/web/js_widget.dart'
    if (dart.library.io) 'src/mobile/js_widget.dart';
