import 'dart:io';

import '../utils.dart';

void updateFirebaseInitialization(
    List<String> platforms, List<String> arguments,
    {bool firebaseAnalytics = false}) {
  // Get Firebase configuration values
  String? androidApiKey = getArgumentValue(arguments, 'android_apiKey',
      required: platforms.contains('android'));
  String? androidAppId = getArgumentValue(arguments, 'android_appId',
      required: platforms.contains('android'));
  String? androidMessagingSenderId = getArgumentValue(
      arguments, 'android_messagingSenderId',
      required: platforms.contains('android'));
  String? androidProjectId = getArgumentValue(arguments, 'android_projectId',
      required: platforms.contains('android'));

  String? iosApiKey = getArgumentValue(arguments, 'ios_apiKey',
      required: platforms.contains('ios'));
  String? iosAppId = getArgumentValue(arguments, 'ios_appId',
      required: platforms.contains('ios'));
  String? iosMessagingSenderId = getArgumentValue(
      arguments, 'ios_messagingSenderId',
      required: platforms.contains('ios'));
  String? iosProjectId = getArgumentValue(arguments, 'ios_projectId',
      required: platforms.contains('ios'));

  String? webApiKey = getArgumentValue(arguments, 'web_apiKey',
      required: platforms.contains('web'));
  String? webAppId = getArgumentValue(arguments, 'web_appId',
      required: platforms.contains('web'));
  String? webAuthDomain = getArgumentValue(arguments, 'web_authDomain',
      required: platforms.contains('web'));
  String? webMessagingSenderId = getArgumentValue(
      arguments, 'web_messagingSenderId',
      required: platforms.contains('web'));
  String? webProjectId = getArgumentValue(arguments, 'web_projectId',
      required: platforms.contains('web'));
  String? webStorageBucket = getArgumentValue(arguments, 'web_storageBucket',
      required: platforms.contains('web'));
  String? webMeasurementId = getArgumentValue(arguments, 'web_measurementId',
      required: platforms.contains('web'));

  if (firebaseAnalytics) {
    uncommentFirebaseAnalyticsConfig(platforms, arguments);
  }

  final buffer = StringBuffer();
  buffer.writeln('FirebaseOptions? androidPayload;');
  buffer.writeln('        FirebaseOptions? iosPayload;');
  buffer.writeln('        FirebaseOptions? webPayload;');

  if (platforms.contains('android')) {
    buffer.writeln('        androidPayload = const FirebaseOptions(');
    buffer.writeln('          apiKey: "$androidApiKey",');
    buffer.writeln('          appId: "$androidAppId",');
    buffer.writeln('          messagingSenderId: "$androidMessagingSenderId",');
    buffer.writeln('          projectId: "$androidProjectId",');
    buffer.writeln('        );');
  }

  if (platforms.contains('ios')) {
    buffer.writeln('        iosPayload = const FirebaseOptions(');
    buffer.writeln('          apiKey: "$iosApiKey",');
    buffer.writeln('          appId: "$iosAppId",');
    buffer.writeln('          messagingSenderId: "$iosMessagingSenderId",');
    buffer.writeln('          projectId: "$iosProjectId",');
    buffer.writeln('        );');
  }

  if (platforms.contains('web')) {
    buffer.writeln('        webPayload = const FirebaseOptions(');
    buffer.writeln('          apiKey: "$webApiKey",');
    buffer.writeln('          appId: "$webAppId",');
    buffer.writeln('          authDomain: "$webAuthDomain",');
    buffer.writeln('          messagingSenderId: "$webMessagingSenderId",');
    buffer.writeln('          projectId: "$webProjectId",');
    buffer.writeln('          storageBucket: "$webStorageBucket",');
    buffer.writeln('          measurementId: "$webMeasurementId",');
    buffer.writeln('        );');
  }

  buffer.writeln('        FirebaseOptions? selectedPayload;');
  buffer.writeln('        if (Platform.isAndroid) {');
  buffer.writeln('          selectedPayload = androidPayload;');
  buffer.writeln('        } else if (Platform.isIOS) {');
  buffer.writeln('          selectedPayload = iosPayload;');
  buffer.writeln('        }');
  buffer.writeln('        if (kIsWeb) {');
  buffer.writeln('          selectedPayload = webPayload;');
  buffer.writeln('        }');
  buffer.writeln(
      '        await Firebase.initializeApp(options: selectedPayload);');

  String newCode = buffer.toString().trim();

  // Now replace the Firebase initialization code in the file
  final File file = File(ensembleModulesFilePath);
  String content = file.readAsStringSync();

  // Regular expression to match the current Firebase initialization block
  final regex = RegExp(
    r'await\s*Firebase\.initializeApp\(\);',
    dotAll: true,
  );

  // Replace the existing Firebase initialization block with the new code
  if (regex.hasMatch(content)) {
    content = content.replaceFirst(regex, newCode);
  }

  file.writeAsStringSync(content);
}

void uncommentFirebaseAnalyticsConfig(
  List<String> platforms,
  List<String> arguments,
) {
  try {
    final file = File(ensembleConfigFilePath);
    if (!file.existsSync()) {
      throw Exception('Config file not found.');
    }

    String enableConsoleLogs =
        getArgumentValue(arguments, 'enableConsoleLogs') ?? 'true';

    String content = file.readAsStringSync();

    // Replace the analytics block
    content = content.replaceAllMapped(
      RegExp(
          r'#\s*analytics:\s*\n#\s*provider:\s*firebase\s*\n#\s*enabled:\s*true\s*\n#\s*enableConsoleLogs:\s*true',
          multiLine: true),
      (match) =>
          'analytics:\n  provider: firebase\n  enabled: true\n  enableConsoleLogs: $enableConsoleLogs',
    );

    if (platforms.contains('web')) {
      String? webApiKey = getArgumentValue(arguments, 'web_apiKey',
          required: platforms.contains('web'));
      String? webAppId = getArgumentValue(arguments, 'web_appId',
          required: platforms.contains('web'));
      String? webAuthDomain = getArgumentValue(arguments, 'web_authDomain',
          required: platforms.contains('web'));
      String? webMessagingSenderId = getArgumentValue(
          arguments, 'web_messagingSenderId',
          required: platforms.contains('web'));
      String? webProjectId = getArgumentValue(arguments, 'web_projectId',
          required: platforms.contains('web'));
      String? webStorageBucket = getArgumentValue(
          arguments, 'web_storageBucket',
          required: platforms.contains('web'));
      String? webMeasurementId = getArgumentValue(
          arguments, 'web_measurementId',
          required: platforms.contains('web'));

      // List of fields to be replaced in the accounts section
      final fields = {
        'apiKey': webApiKey,
        'authDomain': webAuthDomain,
        'projectId': webProjectId,
        'storageBucket': webStorageBucket,
        'messagingSenderId': webMessagingSenderId,
        'appId': webAppId,
        'measurementId': webMeasurementId
      };

      // Regex for uncommenting the Firebase accounts section
      final accountLines = [
        '#\\s*accounts:',
        '#\\s*firebase:',
        '#\\s*web:',
      ];

      // Uncomment the Firebase accounts structure
      for (final line in accountLines) {
        content =
            content.replaceAllMapped(RegExp(line, multiLine: true), (match) {
          return match[0]!.replaceFirst('#', '');
        });
      }

      // Replace the fields inside the accounts section
      fields.forEach((key, value) {
        content = content.replaceAllMapped(
          RegExp('#\\s*$key:\\s*".*"', multiLine: true),
          (match) => '      $key: "$value"',
        );
      });
    }

    // Write the updated content back to the file
    file.writeAsStringSync(content);
    print('ensemble-config.yaml updated successfully.');
  } catch (e) {
    throw Exception('Failed to update ensemble-config.yaml: $e');
  }
}
