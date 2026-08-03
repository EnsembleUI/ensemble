import 'dart:convert';
import 'dart:io';

/// Replaces a file in one rename operation so readers never see a partial file.
class AtomicFile {
  static void writeBytesSync(File target, List<int> bytes) {
    target.parent.createSync(recursive: true);
    final temporary = File(
      '${target.path}.tmp-${pid}-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      temporary.writeAsBytesSync(bytes, flush: true);
      temporary.renameSync(target.path);
    } finally {
      if (temporary.existsSync()) temporary.deleteSync();
    }
  }

  static void writeStringSync(
    File target,
    String contents, {
    Encoding encoding = utf8,
  }) {
    writeBytesSync(target, encoding.encode(contents));
  }
}
