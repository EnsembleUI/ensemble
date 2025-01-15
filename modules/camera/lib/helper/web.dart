import 'stub.dart' if (dart.library.html) 'dart:html' as html;

class Blob {
  final dynamic _blob;

  Blob(List<dynamic> array, String type)
      : _blob = html.Blob(array, type);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) {
    return html.Url.createObjectUrlFromBlob(blob._blob);
  }
}
