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
