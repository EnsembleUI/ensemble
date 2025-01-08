import 'dart:html' as html;
import 'package:flutter/foundation.dart';

Future<void> downloadFileOnWeb(String fileName, Uint8List fileBytes) async {
  try {
    // Convert Uint8List to a Blob
    final blob = html.Blob([fileBytes]);

    // Create an object URL for the Blob
    final url = html.Url.createObjectUrlFromBlob(blob);

    // Create a download anchor element
    final anchor = html.AnchorElement(href: url)
      ..target = 'blank' // Open in a new tab if needed
      ..download = fileName; // Set the download file name

    // Trigger the download
    anchor.click();

    // Revoke the object URL to free resources
    html.Url.revokeObjectUrl(url);

    debugPrint('File downloaded: $fileName');
  } catch (e) {
    throw Exception('Failed to download file: $e');
  }
}
