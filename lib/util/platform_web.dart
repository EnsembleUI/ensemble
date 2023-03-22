/// only import on web platform, use in conjunction with platform_stub.dart

import 'dart:js';

bool get isHtmlRenderer => context['flutterCanvasKit'] == null;
