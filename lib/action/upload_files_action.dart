import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/toast.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:ensemble/util/upload_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:yaml/yaml.dart';

Future<void> uploadFiles({
  required BuildContext context,
  required FileUploadAction action,
  required DataContext dataContext,
  ScopeManager? scopeManager,
  Map<String, YamlMap>? apiMap,
}) async {
  List<File>? selectedFiles = _getRawFiles(action.files, dataContext);

  if (selectedFiles == null) {
    if (action.onError != null) {
      ScreenController().executeAction(context, action.onError!);
    }
    return;
  }

  if (isFileSizeOverLimit(context, dataContext, selectedFiles, action)) {
    if (action.onError != null) {
      ScreenController().executeAction(context, action.onError!);
    }
    return;
  }

  if (action.id != null && scopeManager != null) {
    final uploadFilesResponse =
        scopeManager.dataContext.getContextById(action.id!);
    scopeManager.dataContext.addInvokableContext(
        action.id!,
        (uploadFilesResponse is UploadFilesResponse)
            ? uploadFilesResponse
            : UploadFilesResponse());
  }

  final apiDefinition = apiMap?[action.uploadApi];
  if (apiDefinition == null) {
    throw LanguageError(
        'Unable to find api definition for ${action.uploadApi}');
  }

  if (apiDefinition['inputs'] is YamlList && action.inputs != null) {
    for (var input in apiDefinition['inputs']) {
      final value = dataContext.eval(action.inputs![input]);
      if (value != null) {
        dataContext.addDataContextById(input, value);
      }
    }
  }

  Map<String, String> headers = {};
  if (apiDefinition['headers'] is YamlMap) {
    (apiDefinition['headers'] as YamlMap).forEach((key, value) {
      if (value != null) {
        headers[key.toString()] = dataContext.eval(value).toString();
      }
    });
  }

  Map<String, String> fields = {};
  if (apiDefinition['body'] is YamlMap) {
    (apiDefinition['body'] as YamlMap).forEach((key, value) {
      if (value != null) {
        fields[key.toString()] = dataContext.eval(value).toString();
      }
    });
  }
  String rawUrl = apiDefinition['url']?.toString().trim() ??
      apiDefinition['uri']?.toString().trim() ??
      '';

  String url = HTTPAPIProvider.resolveUrl(dataContext, rawUrl);
  String method = apiDefinition['method']?.toString().toUpperCase() ?? 'POST';
  final fileResponse = action.id == null
      ? null
      : scopeManager?.dataContext.getContextById(action.id!)
          as UploadFilesResponse;

  List<List<File>> fileBatches;
  if (action.batchSize != null) {
    fileBatches = [];
    for (int i = 0; i < selectedFiles.length; i += action.batchSize!) {
      int end = (i + action.batchSize! < selectedFiles.length)
          ? i + action.batchSize!
          : selectedFiles.length;
      fileBatches.add(selectedFiles.sublist(i, end));
    }
  } else {
    fileBatches = [selectedFiles];
  }

  for (var fileBatch in fileBatches) {
    if (action.isBackgroundTask) {
      if (kIsWeb) {
        throw LanguageError('Background Upload is not supported on web');
      }
      await _setBackgroundUploadTask(
        context: context,
        action: action,
        selectedFiles: fileBatch,
        headers: headers,
        fields: fields,
        method: method,
        url: url,
        fileResponse: fileResponse,
        scopeManager: scopeManager,
      );

      return;
    }
    final taskId = Utils.generateRandomId(8);
    fileResponse?.addTask(UploadTask(id: taskId));

    final response = await UploadUtils.uploadFiles(
      headers: headers,
      fields: fields,
      method: method,
      url: url,
      files: fileBatch,
      fieldName: action.fieldName,
      showNotification: action.showNotification,
      onError: action.onError == null
          ? null
          : (error) =>
              ScreenController().executeAction(context, action.onError!),
      progressCallback: (progress) {
        fileResponse?.setProgress(taskId, progress);
        scopeManager?.dispatch(
            ModelChangeEvent(APIBindingSource(action.id!), fileResponse));
      },
      taskId: taskId,
    );

    if (response == null) {
      fileResponse?.setStatus(taskId, UploadStatus.failed);
      return;
    }
    fileResponse?.setHeaders(taskId, response.headers);
    fileResponse?.setBody(taskId, response.body);
    fileResponse?.setStatus(taskId, UploadStatus.completed);
    scopeManager?.dispatch(
        ModelChangeEvent(APIBindingSource(action.id!), fileResponse));

    if (action.onComplete != null) {
      // TODO: @snehmehta, fix this
      ScreenController().executeAction(context, action.onComplete!);
    }
  }
}

List<File>? _getRawFiles(dynamic rawFiles, DataContext dataContext) {
  var files = dataContext.eval(rawFiles);
  if (files is YamlList || files is List) {
    return files
        .map((element) {
          if (element is String) {
            return File.fromString(element);
          }
          return File.fromJson(element);
        })
        .toList()
        .cast<File>();
  }

  if (files is Map && files.containsKey('path')) {
    return [File.fromJson(files)];
  }

  if (files is String) {
    final rawFiles = File.fromString(files);
    return [rawFiles];
  }

  return null;
}

bool isFileSizeOverLimit(BuildContext context, DataContext dataContext,
    List<File> selectedFiles, FileUploadAction action) {
  final defaultMaxFileSize = 100.mb;
  const defaultOverMaxFileSizeMessage =
      'The size of is which is larger than the maximum allowed';

  final totalSize = selectedFiles.fold<double>(
      0, (previousValue, element) => previousValue + (element.size ?? 0));
  final maxFileSize = action.maxFileSize?.kb ?? defaultMaxFileSize;

  final message = Utils.translateWithFallback(
    'ensemble.input.overMaxFileSizeMessage',
    action.overMaxFileSizeMessage ?? defaultOverMaxFileSizeMessage,
  );

  if (totalSize > maxFileSize) {
    ToastController().showToast(
        context,
        ShowToastAction(
            type: ToastType.error,
            message: message,
            alignment: Alignment.bottomCenter,
            duration: 3),
        null,
        dataContext: dataContext);
    if (action.onError != null) {
      ScreenController().executeAction(context, action.onError!);
    }
    return true;
  }
  return false;
}

Future<void> _setBackgroundUploadTask({
  required BuildContext context,
  required FileUploadAction action,
  required List<File> selectedFiles,
  required Map<String, String> headers,
  required Map<String, String> fields,
  required String method,
  required String url,
  UploadFilesResponse? fileResponse,
  ScopeManager? scopeManager,
}) async {
  final taskId = Utils.generateRandomId(8);
  fileResponse?.addTask(UploadTask(id: taskId, isBackground: true));

  await Workmanager().registerOneOffTask(
    'uploadTask',
    backgroundUploadTask,
    tag: taskId,
    inputData: {
      'fieldName': action.fieldName,
      'files': selectedFiles.map((e) => json.encode(e.toJson())).toList(),
      'headers': json.encode(headers),
      'fields': json.encode(fields),
      'method': method,
      'url': url,
      'taskId': taskId,
      'showNotification': action.showNotification,
    },
    constraints: Constraints(
      networkType: NetworkTypeExtension.fromString(action.networkType),
      requiresBatteryNotLow: action.requiresBatteryNotLow,
    ),
  );

  var port = ReceivePort();
  IsolateNameServer.registerPortWithName(port.sendPort, taskId);
  StreamSubscription<dynamic>? subscription;
  subscription = port.listen((dynamic data) async {
    if (data is! Map) return;
    if (data.containsKey('progress')) {
      final taskId = data['taskId'];
      fileResponse?.setStatus(taskId, UploadStatus.running);
      fileResponse?.setProgress(taskId, data['progress']);
      if (action.id != null) {
        scopeManager?.dispatch(
            ModelChangeEvent(APIBindingSource(action.id!), fileResponse));
      }
    }

    if (data.containsKey('cancel')) {
      if (action.id != null) {
        scopeManager?.dispatch(
            ModelChangeEvent(APIBindingSource(action.id!), fileResponse));
      }
      subscription?.cancel();
    }

    if (data.containsKey('error')) {
      final taskId = data['taskId'];
      fileResponse?.setStatus(taskId, UploadStatus.failed);
      if (action.id != null) {
        scopeManager?.dispatch(
            ModelChangeEvent(APIBindingSource(action.id!), fileResponse));
      }
      if (action.onError != null) {
        ScreenController().executeAction(context, action.onError!);
      }
      subscription?.cancel();
    }
    if (data.containsKey('responseBody')) {
      final taskId = data['taskId'];
      final response =
        HttpResponse.fromBody(data['responseBody'], data['responseHeaders']);
      fileResponse?.setBody(taskId, response.body);
      fileResponse?.setHeaders(taskId, response.headers);
      fileResponse?.setStatus(taskId, UploadStatus.completed);

      if (action.id != null) {
        scopeManager?.dispatch(
            ModelChangeEvent(APIBindingSource(action.id!), fileResponse));
      }

      if (action.onComplete != null) {
        ScreenController().executeAction(context, action.onComplete!);
      }
      subscription?.cancel();
    }
  });
}

extension NetworkTypeExtension on NetworkType {
  static NetworkType fromString(String? str) {
    if (str == null) return NetworkType.connected;
    switch (str.toLowerCase()) {
      case 'connected':
        return NetworkType.connected;
      case 'metered':
        return NetworkType.metered;
      case 'not_required':
        return NetworkType.not_required;
      case 'not_roaming':
        return NetworkType.not_roaming;
      case 'unmetered':
        return NetworkType.unmetered;
      case 'temporarily_unmetered':
        return NetworkType.temporarily_unmetered;
      default:
        return NetworkType.connected;
    }
  }
}
