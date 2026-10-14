import 'dart:io';

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '0');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  await for (final request in server) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write('{"status":"ready"}');
    await request.response.close();
  }
}
