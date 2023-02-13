import 'dart:async';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/util/http_utils.dart';
import 'package:http/http.dart' as http;

typedef ProgressCallback = void Function(double progress);
typedef OnDoneCallback = void Function();
typedef OnErrorCallback = void Function(dynamic error);

class UploadUtils {
  
  static Future<Response?> uploadFiles(
      String url, 
      List<File> files, 
      {
        ProgressCallback? progressCallback,
        OnDoneCallback? onDone,
        OnErrorCallback? onError,
      }
    ) async {
    final request = MultipartRequest(
      'POST',
      Uri.parse(url),  
      onProgress: (int bytes, int total) {
        final progress = bytes / total;
        progressCallback?.call(progress);
      }
  );
    final multipartFiles = <http.MultipartFile>[];
  
    for (var file in files) {
      if (file.path == null) continue;
      final multipartFile = await http.MultipartFile.fromPath('files', file.path!);
      multipartFiles.add(multipartFile);
    }

    request.files.addAll(multipartFiles);

    try {
      final response = await request.send();
      
      if (response.statusCode >= 200 && response.statusCode <= 300) {
        onDone?.call();
        final res = await http.Response.fromStream(response);
        return Response(res);
      } else {
        throw Exception('Failed to upload file');
      }
    } catch (error) {
      onError?.call(error);
    }
    return null;
    
  }
}


class MultipartRequest extends http.MultipartRequest {
  MultipartRequest(
    String method,
    Uri url, {
    this.onProgress,
  }) : super(method, url);

  final void Function(int bytes, int totalBytes)? onProgress;

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) return byteStream;

    final total = contentLength;
    int bytes = 0;

    final t = StreamTransformer.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        bytes = data.length;
        onProgress?.call(bytes, total);
        if(total >= bytes) {
           sink.add(data);
        }
      }
    );
    final stream = byteStream.transform(t);
    return http.ByteStream(stream);
  }
}
