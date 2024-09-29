import 'dart:io';

// To read file content
String readFileContent(String filePath) {
  File file = File(filePath);
  if (!file.existsSync()) {
    throw Exception('Error: $filePath not found.');
  }
  return file.readAsStringSync();
}

// To update content using regex
String updateContent(String content, String regexPattern, String replacement) {
  return content.replaceAllMapped(
    RegExp(regexPattern),
    (match) => replacement,
  );
}

// To write updated content to file
void writeFileContent(String filePath, String content) {
  File file = File(filePath);
  file.writeAsStringSync(content);
}
