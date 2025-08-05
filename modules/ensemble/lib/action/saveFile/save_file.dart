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
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      // FIX: Evaluate fileName expression using scope manager
      dynamic evaluatedFileName = scopeManager.dataContext.eval(fileName);
      String? finalFileName = evaluatedFileName?.toString().trim();
      
      if (finalFileName == null || finalFileName.isEmpty) {
        throw Exception('Missing or empty fileName parameter.');
      }

      // FIX: Evaluate type expression using scope manager
      dynamic evaluatedType = scopeManager.dataContext.eval(type);
      String? finalType = evaluatedType?.toString().trim();
      
      if (finalType == null || finalType.isEmpty) {
        throw Exception('Missing or empty type parameter.');
      }

      Uint8List? fileBytes;

      // If blobData is provided, process it
      if (blobData != null) {
        dynamic evaluatedBlobData = scopeManager.dataContext.eval(blobData);
        
        // Handle base64 blob or binary data
        if (evaluatedBlobData is String) {
          fileBytes = base64Decode(evaluatedBlobData); // Decode base64
        } else if (evaluatedBlobData is List<int>) {
          fileBytes = Uint8List.fromList(evaluatedBlobData);
        } else {
          throw Exception(
              'Invalid blob data format. Must be base64 or List<int>.');
        }
      } else if (source != null) {
        dynamic evaluatedSource = scopeManager.dataContext.eval(source);
        String? sourceUrl = evaluatedSource?.toString().trim();

        if (sourceUrl == null || sourceUrl.isEmpty) {
          throw Exception('Source URL is null or empty after evaluation');
        }

        // FIX: Handle URLs with spaces by encoding them
        String encodedUrl = Uri.encodeFull(sourceUrl);
        final response = await http.get(Uri.parse(encodedUrl));
        
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
      await _saveFile(finalType, finalFileName, fileBytes);
      
      if (onComplete != null) {
        await ScreenController().executeAction(
          context,
          onComplete!,
          event: EnsembleEvent(initiator, data: {
            'fileBytes': fileBytes,
            'fileName': finalFileName,
          }),
        );
      }
    } catch (e) {
      if (onError != null) {
        await ScreenController().executeAction(
          context,
          onError!,
          event: EnsembleEvent(initiator, error: e.toString()),
        );
      }
    }
  }

  Future<void> _saveFile(
      String type, String fileName, Uint8List fileBytes) async {
    if (type == 'image') {
      // Save images to Default Image Path
      await saveImageToDCIM(fileName, fileBytes);
    } else if (type == 'document') {
      // Save documents to Documents folder
      await saveDocumentToDocumentsFolder(fileName, fileBytes);
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
