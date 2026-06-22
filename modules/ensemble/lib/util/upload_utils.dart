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

/// Returns true when [path] contains a `..` path segment after normalising `\`
/// to `/`.
///
/// Used before [http.MultipartFile.fromPath] so partially trusted paths (for
/// example from API JSON bound into [FileUploadAction] inputs) cannot traverse
/// out of an intended directory when reading bytes from disk.
bool uploadPathContainsParentSegment(String? path) {
  if (path == null || path.isEmpty) return false;
  final unified = path.replaceAll(r'\', '/');
  for (final segment in unified.split('/')) {
    if (segment == '..') return true;
  }
  return false;
}

/// Splits [files] into upload batches of at most [batchSize] items.
///
/// When [batchSize] is null, returns a single batch containing all [files].
List<List<T>> splitUploadFileBatches<T>(List<T> files, int? batchSize) {
  if (batchSize == null) {
    return [files];
  }
  final batches = <List<T>>[];
  for (var i = 0; i < files.length; i += batchSize) {
    final end = i + batchSize < files.length ? i + batchSize : files.length;
    batches.add(files.sublist(i, end));
  }
  return batches;
}

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
      if (file.path != null && uploadPathContainsParentSegment(file.path)) {
        throw FormatException(
            'Upload file path cannot contain ".." segments: ${file.path}');
      }
      http.MultipartFile? multipartFile;
      final mimeType =
          lookupMimeType(file.path ?? '', headerBytes: file.bytes) ??
              'application/octet-stream';
      if (file.bytes != null) {
        final mediaType = MediaType.parse(mimeType);
        final filename = file.name?.isNotEmpty ?? false
            ? file.name
            : generateFileName(mediaType);
        multipartFile = http.MultipartFile.fromBytes(
            file.fieldName ?? fieldName, file.bytes!,
            filename: filename, contentType: mediaType);
      } else if (file.path != null) {
        multipartFile = await http.MultipartFile.fromPath(
            file.fieldName ?? fieldName, file.path!,
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

      final res = await http.Response.fromStream(response);
      if (res.statusCode >= 200 && res.statusCode <= 300) {
        return HttpResponse(res, APIState.success);
      } else {
        throw Exception(
            'uploadFile: Failed to upload files \nserver response:\n${res.body}');
      }
    } catch (error) {
      onError?.call(error);
    }
    return null;
  }

  static generateFileName(MediaType mediaType) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${mediaType.type}_$timestamp.${mediaType.subtype}';
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
