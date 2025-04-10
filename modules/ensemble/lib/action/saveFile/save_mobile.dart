import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ensemble/framework/stub/file_manager.dart';

import 'download_stub.dart' if (dart.library.html) 'download_web.dart';

Future<void> saveImageToDCIM(String fileName, Uint8List fileBytes) async {
  try {
    if (kIsWeb) {
      downloadFileOnWeb(fileName, fileBytes);
    } else {
      await GetIt.I<FileManager>().saveImage(
        fileBytes,
        name: fileName,
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
      downloadFileOnWeb(fileName, fileBytes);
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
