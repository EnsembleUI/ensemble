import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:dio/dio.dart';

/// Custom action to save files (images and documents) in platform-specific accessible directories
class SaveToFileSystemAction extends EnsembleAction {
  final String? fileName;
  final dynamic blobData;
  final String? source; // Optional source for URL if blobData is not available

  SaveToFileSystemAction({
    required this.fileName,
    this.blobData,
    this.source,
  });

  factory SaveToFileSystemAction.from({Map? payload}) {
    if (payload == null || payload['fileName'] == null) {
      throw LanguageError('${ActionType.saveFile.name} requires fileName.');
    }

    return SaveToFileSystemAction(
      fileName: payload['fileName'],
      blobData: payload['blobData'],
      source: payload['source'],
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
        Dio dio = Dio();
        var response = await dio.get(source!,
            options: Options(responseType: ResponseType.bytes));
        fileBytes = Uint8List.fromList(response.data);
      } else {
        throw Exception('Missing blobData and source.');
      }

      // Determine file type based on file extension
      final fileExtension = fileName!.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(fileExtension)) {
        // Save images to DCIM/Pictures
        await _saveImageToDCIM(fileName!, fileBytes!);
      } else {
        // Save documents to Documents folder
        await _saveDocumentToDocumentsFolder(fileName!, fileBytes!);
      }
    } catch (e) {
      print('Error saving file: $e');
      throw Exception('Failed to save file: $e');
    }
  }

  /// Save images to DCIM/Pictures folder
  Future<void> _saveImageToDCIM(String fileName, Uint8List fileBytes) async {
    try {
      // Get DCIM directory
      final directory = Directory('/storage/emulated/0/DCIM/Pictures');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Save file
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      print('Image saved to DCIM/Pictures: $filePath');
    } catch (e) {
      print('Error saving image to DCIM/Pictures: $e');
      throw Exception('Failed to save image: $e');
    }
  }

  /// Save documents to Documents folder
  Future<void> _saveDocumentToDocumentsFolder(
      String fileName, Uint8List fileBytes) async {
    try {
      // Get Documents directory
      final directory = Directory('/storage/emulated/0/Documents');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Save file
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      print('Document saved to Documents folder: $filePath');
    } catch (e) {
      print('Error saving document to Documents folder: $e');
      throw Exception('Failed to save document: $e');
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
