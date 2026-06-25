// #region agent log
import 'dart:convert';
import 'dart:io';

void agentDebugLog(
  String hypothesisId,
  String location,
  String message,
  Map<String, Object?> data,
) {
  final payload = <String, Object?>{
    'sessionId': 'cab532',
    'id': 'log_${DateTime.now().microsecondsSinceEpoch}',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'runId': 'timeout-analysis',
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
  };
  try {
    File(
        '/Users/sharjeelyunus/Desktop/Ensemble/ensemble/.cursor/debug-cab532.log')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('${jsonEncode(payload)}\n', mode: FileMode.append);
  } catch (_) {}
}
// #endregion
