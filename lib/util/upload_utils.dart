import 'dart:async';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/util/http_utils.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

typedef ProgressCallback = void Function(double progress);
typedef OnDoneCallback = void Function();
typedef OnErrorCallback = void Function(dynamic error);

class UploadUtils {
  
  static Future<Response?> uploadFiles(
      YamlMap api, 
      DataContext eContext,
      List<File> files, 
      {
        ProgressCallback? progressCallback,
        OnDoneCallback? onDone,
        OnErrorCallback? onError,
      }
    ) async {

    Map<String, String> headers = {};
    if (api['headers'] is YamlMap) {
      (api['headers'] as YamlMap).forEach((key, value) {
        if (value != null) {
          headers[key.toString()] = eContext.eval(value).toString();
        }
      });
    }
    
    String url = HttpUtils.resolveUrl(eContext, api['uri'].toString().trim());
    String method = api['method']?.toString().toUpperCase() ?? 'POST';

    final request = MultipartRequest(
      method,
      Uri.parse(url),  
      onProgress: progressCallback == null ? null : (int bytes, int total) {
        final progress = bytes / total;
        progressCallback.call(progress);
      }
    );
    request.headers.addAll(headers);
    final multipartFiles = <http.MultipartFile>[];

    for (var file in files) {
      http.MultipartFile? multipartFile;

      if (file.path != null) {
        multipartFile = await http.MultipartFile.fromPath('files', file.path!);
      } else if ( file.bytes != null ) {
        multipartFile = http.MultipartFile.fromBytes('files', file.bytes!, filename: file.name);
      } else {
        continue;
      }

      multipartFiles.add(multipartFile);
    }

    request.files.addAll(multipartFiles);

    try {
      final response = await request.send();
      
      if (response.statusCode >= 200 && response.statusCode <= 300) {
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
        bytes += data.length;
        if(total >= bytes) {
          sink.add(data);
          onProgress?.call(bytes, total);
        }
      }, 
    );
    final stream = byteStream.transform(t);
    return http.ByteStream(stream);
  }
}
