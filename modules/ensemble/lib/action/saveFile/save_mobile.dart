import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ensemble/framework/stub/file_manager.dart';

import 'download_stub.dart' if (dart.library.html) 'download_web.dart';

Future<void> saveImageToDCIM(String fileName, Uint8List fileBytes) async {
  try {
    final safeFileName = sanitizeFileName(fileName);
    if (kIsWeb) {
      downloadFileOnWeb(safeFileName, fileBytes);
    } else {
      await GetIt.I<FileManager>().saveImage(
        fileBytes,
        name: safeFileName,
      );
    }
  } catch (e) {
    throw Exception('Failed to save image: $e');
  }
}

/// Save documents to the default "Documents" directory
Future<void> saveDocumentToDocumentsFolder(
    String fileName, Uint8List fileBytes) async {
  try {
    final safeFileName = sanitizeFileName(fileName);
    String filePath;

    if (Platform.isAndroid) {
      // Get the default "Documents" directory on Android
      Directory? directory = Directory('/storage/emulated/0/Documents');
      if (!directory.existsSync()) {
        directory.createSync(
            recursive: true); // Create the directory if it doesn't exist
      }
      filePath = '${directory.path}/$safeFileName';
    } else if (Platform.isIOS) {
      // On iOS, use the app-specific Documents directory
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/$safeFileName';

      // Optionally, use a share intent to let users save the file to their desired location
    } else if (kIsWeb) {
      downloadFileOnWeb(safeFileName, fileBytes);
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

String sanitizeFileName(String fileName) {
  final trimmed = fileName.trim();
  final lowerFileName = trimmed.toLowerCase();
  final hasUnsafeSegment = trimmed.isEmpty ||
      trimmed == '.' ||
      trimmed == '..' ||
      trimmed.contains('/') ||
      trimmed.contains(r'\') ||
      lowerFileName.contains('%2f') ||
      lowerFileName.contains('%5c') ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(trimmed);

  if (hasUnsafeSegment) {
    throw ArgumentError.value(fileName, 'fileName', 'Invalid file name');
  }
  return trimmed;
}
