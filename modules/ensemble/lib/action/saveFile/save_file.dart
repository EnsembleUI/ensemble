import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// Conditionally import the file that has `dart:html` vs. the stub:
import 'download_stub.dart' if (dart.library.html) 'download_web.dart';

/// Custom action to save files (images and documents) in platform-specific accessible directories
class SaveToFileSystemAction extends EnsembleAction {
  final String? fileName;
  final dynamic blobData;
  final String? source; // Optional source for URL if blobData is not available
  final String? type; // file type

  SaveToFileSystemAction({
    required this.fileName,
    this.blobData,
    this.source,
    this.type,
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

      if (type == 'image') {
        // Save images to Default Image Path
        await _saveImageToDCIM(fileName!, fileBytes);
      } else if (type == 'document') {
        // Save documents to Documents folder
        await _saveDocumentToDocumentsFolder(fileName!, fileBytes);
      }
    } catch (e) {
      throw Exception('Failed to save file: $e');
    }
  }

  Future<void> _saveImageToDCIM(String fileName, Uint8List fileBytes) async {
    try {
      if (kIsWeb) {
        _downloadFileOnWeb(fileName, fileBytes);
      } else {
        final result = await ImageGallerySaver.saveImage(
          fileBytes,
          name: fileName,
        );
        if (result['isSuccess']) {
          debugPrint('Image saved to gallery: $result');
        } else {
          throw Exception('Failed to save image to gallery.');
        }
      }
    } catch (e) {
      throw Exception('Failed to save image: $e');
    }
  }

  /// Save documents to the default "Documents" directory
  Future<void> _saveDocumentToDocumentsFolder(
      String fileName, Uint8List fileBytes) async {
    try {
      String filePath;

      if (Platform.isAndroid) {
        // Get the default "Documents" directory on Android
        Directory? directory = Directory('/storage/emulated/0/Documents');
        if (!directory.existsSync()) {
          directory.createSync(
              recursive: true); // Create the directory if it doesn't exist
        }
        filePath = '${directory.path}/$fileName';
      } else if (Platform.isIOS) {
        // On iOS, use the app-specific Documents directory
        final directory = await getApplicationDocumentsDirectory();
        filePath = '${directory.path}/$fileName';

        // Optionally, use a share intent to let users save the file to their desired location
      } else if (kIsWeb) {
        _downloadFileOnWeb(fileName, fileBytes);
        return;
      } else {
        throw UnsupportedError('Platform not supported');
      }

      // Write the file to the determined path
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      debugPrint('Document saved to: $filePath');
    } catch (e) {
      throw Exception('Failed to save document: $e');
    }
  }

  Future<void> _downloadFileOnWeb(String fileName, Uint8List fileBytes) async {
    downloadFileOnWeb(fileName, fileBytes);
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
