// Stub implementation for non-web platforms
library web;

class Blob {
  Blob(List<dynamic> array, String type) {
    throw UnsupportedError('Blob is only supported on web platforms');
  }
}

class Url {
  static String createObjectUrlFromBlob(dynamic blob) {
    throw UnsupportedError('URL.createObjectURL is only supported on web platforms');
  }
}

class JsObject {
  JsObject(dynamic constructor, [List<dynamic>? arguments]) {
    throw UnsupportedError('JsObject is only supported on web platforms');
  }
  static dynamic jsify(Object object) {
    throw UnsupportedError('JsObject.jsify is only supported on web platforms');
  }
  void operator []=(String property, dynamic value) {
    throw UnsupportedError('Property assignment is only supported on web platforms');
  }
  dynamic operator [](String property) {
    throw UnsupportedError('Property access is only supported on web platforms');
  }
  dynamic callMethod(String method, [List<dynamic>? args]) {
    throw UnsupportedError('callMethod is only supported on web platforms');
  }
}

dynamic allowInterop<T extends Function>(T function) {
  throw UnsupportedError('allowInterop is only supported on web platforms');
}
final JsObject context = JsObject(null);