import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ensemble/framework/stub/file_manager.dart';

import 'download_stub.dart' if (dart.library.html) 'download_web.dart';

/// Returns a single path segment for writes under a fixed parent directory.
/// Rejects empty names, `.`, `..`, embedded `..`, and any path separators.
String sanitizedSaveFileName(String fileName) {
  final normalized = fileName.replaceAll(r'\', '/');
  final slash = normalized.lastIndexOf('/');
  final base = slash == -1 ? normalized : normalized.substring(slash + 1);
  if (base.isEmpty || base == '.' || base == '..' || base.contains('..')) {
    throw FormatException(
        'Invalid fileName: only a base name is allowed (no path segments).');
  }
  return base;
}

Future<void> saveImageToDCIM(String fileName, Uint8List fileBytes) async {
  try {
    final safeName = sanitizedSaveFileName(fileName);
    if (kIsWeb) {
      downloadFileOnWeb(safeName, fileBytes);
    } else {
      await GetIt.I<FileManager>().saveImage(
        fileBytes,
        name: safeName,
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
    final safeName = sanitizedSaveFileName(fileName);
    String filePath;

    if (Platform.isAndroid) {
      // Get the default "Documents" directory on Android
      Directory? directory = Directory('/storage/emulated/0/Documents');
      if (!directory.existsSync()) {
        directory.createSync(
            recursive: true); // Create the directory if it doesn't exist
      }
      filePath = '${directory.path}/$safeName';
    } else if (Platform.isIOS) {
      // On iOS, use the app-specific Documents directory
      final directory = await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/$safeName';

      // Optionally, use a share intent to let users save the file to their desired location
    } else if (kIsWeb) {
      downloadFileOnWeb(safeName, fileBytes);
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
