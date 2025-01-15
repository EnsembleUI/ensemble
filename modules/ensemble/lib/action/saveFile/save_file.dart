import 'dart:convert';
import 'dart:typed_data';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'save_mobile.dart';

/// Custom action to save files (images and documents) in platform-specific accessible directories
class SaveToFileSystemAction extends EnsembleAction {
  final String? fileName;
  final dynamic blobData;
  final String? source; // Optional source for URL if blobData is not available
  final String? type; // file type
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  SaveToFileSystemAction({
    required this.fileName,
    this.blobData,
    this.source,
    this.type,
    this.onComplete,
    this.onError,
  });

  factory SaveToFileSystemAction.from({Map? payload}) {
    if (payload == null || payload['fileName'] == null) {
      throw LanguageError('${ActionType.saveFile.name} requires fileName.');
    }

    return SaveToFileSystemAction(
      fileName: payload['fileName'],
      blobData: payload['blobData'],
      source: payload['source'],
      type: payload['type'],
      onComplete: payload['onComplete'] != null
          ? EnsembleAction.from(payload['onComplete'])
          : null,
      onError: payload['onError'] != null
          ? EnsembleAction.from(payload['onComplete'])
          : null,
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      if (fileName == null) {
        throw Exception('Missing required parameter: fileName.');
      }

      Uint8List? fileBytes;

      // If blobData is provided, process it
      if (blobData != null) {
        // Handle base64 blob or binary data
        if (blobData is String) {
          fileBytes = base64Decode(blobData); // Decode base64
        } else if (blobData is List<int>) {
          fileBytes = Uint8List.fromList(blobData);
        } else {
          throw Exception(
              'Invalid blob data format. Must be base64 or List<int>.');
        }
      } else if (source != null) {
        // If blobData is not available, check for source (network URL)
        final response = await http.get(Uri.parse(source!));
        if (response.statusCode == 200) {
          fileBytes = Uint8List.fromList(response.bodyBytes);
        } else {
          throw Exception(
              'Failed to download file: HTTP ${response.statusCode}');
        }
      } else {
        throw Exception('Missing blobData and source.');
      }

      // Save the file to the storage system
      await _saveFile(type!, fileName!, fileBytes);
      if (onComplete != null) {
        await ScreenController().executeAction(
          context,
          onComplete!,
          event: EnsembleEvent(initiator, data: {
            'fileBytes': fileBytes,
            'fileName': fileName,
          }),
        );
      }
    } catch (e) {
      if (onError != null) {
        await ScreenController().executeAction(
          context,
          onError!,
          event: EnsembleEvent(initiator, data: {'error': e.toString()}),
        );
      }
    }
  }

  Future<void> _saveFile(
      String type, String fileName, Uint8List fileBytes) async {
    if (type == 'image') {
      // Save images to Default Image Path
      await saveImageToDCIM(fileName!, fileBytes);
    } else if (type == 'document') {
      // Save documents to Documents folder
      await saveDocumentToDocumentsFolder(fileName!, fileBytes);
    }
  }

  /// Factory method to construct the action from JSON
  static SaveToFileSystemAction fromJson(Map<String, dynamic> json) {
    return SaveToFileSystemAction(
      fileName: json['fileName'],
      blobData: json['blobData'],
      source: json['source'],
    );
  }
}
