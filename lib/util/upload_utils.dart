import 'dart:async';

import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/data_context.dart' hide MediaType;
import 'package:ensemble/util/notification_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

typedef ProgressCallback = void Function(double progress);
typedef OnErrorCallback = void Function(dynamic error);

int getInt(String id) {
  return id.codeUnits.reduce((a, b) => a + b);
}

class UploadUtils {
  static Future<HttpResponse?> uploadFiles({
    required String taskId,
    required String method,
    required String url,
    required Map<String, String> headers,
    required Map<String, String> fields,
    required List<File> files,
    required String fieldName,
    bool showNotification = false,
    ProgressCallback? progressCallback,
    OnErrorCallback? onError,
  }) async {
    double previousPercentage = 0.0;

    final request = MultipartRequest(
      method,
      Uri.parse(url),
      onProgress: progressCallback == null
          ? null
          : (int bytes, int total) {
              final progress = bytes / total;
              final percentage = (progress * 100).toInt();

              if (percentage > previousPercentage) {
                previousPercentage = percentage.toDouble();
                progressCallback.call(progress);

                if (showNotification) {
                  notificationUtils.showProgressNotification(percentage,
                      notificationId: getInt(taskId));
                }
              }
            },
    );
    request.headers.addAll(headers);
    final multipartFiles = <http.MultipartFile>[];

    for (var file in files) {
      http.MultipartFile? multipartFile;
      final mimeType =
          lookupMimeType(file.path ?? '', headerBytes: file.bytes) ??
              'application/octet-stream';
      if (file.bytes != null) {
        multipartFile = http.MultipartFile.fromBytes(fieldName, file.bytes!,
            filename: file.name, contentType: MediaType.parse(mimeType));
      } else if (file.path != null) {
        multipartFile = await http.MultipartFile.fromPath(fieldName, file.path!,
            filename: file.name, contentType: MediaType.parse(mimeType));
      } else {
        debugPrint('Failed to add ${file.name} ${file.ext} ${file.path}');
        continue;
      }

      multipartFiles.add(multipartFile);
    }

    request.files.addAll(multipartFiles);
    request.fields.addAll(fields);

    try {
      final response = await request.send();

      if (response.statusCode >= 200 && response.statusCode <= 300) {
        final res = await http.Response.fromStream(response);
        return HttpResponse(res, APIState.success);
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
        if (total >= bytes) {
          sink.add(data);
          onProgress?.call(bytes, total);
        }
      },
    );
    final stream = byteStream.transform(t);
    return http.ByteStream(stream);
  }
}
