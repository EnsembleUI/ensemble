import 'dart:io';

import '../utils.dart';

void updateFirebaseInitialization(
    List<String> platforms, List<String> arguments) {
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

void updateAnalyticsConfig(
  String enableConsoleLogs, {
  String provider = 'firebase',
}) {
  try {
    final file = File(ensembleConfigFilePath);
    if (!file.existsSync()) {
      throw Exception('Config file not found.');
    }

    String content = file.readAsStringSync();

    // Replace the analytics block
    content = content.replaceAllMapped(
      RegExp(
          r'#\s*analytics:\s*\n#\s*provider:\s*firebase\s*\n#\s*enabled:\s*true\s*\n#\s*enableConsoleLogs:\s*true',
          multiLine: true),
      (match) =>
          'analytics:\n  provider: $provider\n  enabled: true\n  enableConsoleLogs: $enableConsoleLogs',
    );

    // Write the updated content back to the file
    file.writeAsStringSync(content);
    print('ensemble-config.yaml updated successfully.');
  } catch (e) {
    throw Exception('Failed to update ensemble-config.yaml: $e');
  }
}

Map<String, String> getFirebaseKeys(String platform, List<String> arguments) {
  const keyPrefixes = {
    'web': 'web_',
    'android': 'android_',
    'ios': 'ios_',
  };

  final prefix = keyPrefixes[platform] ?? '';
  return {
    'apiKey': getArgumentValue(arguments, '${prefix}apiKey') ?? '',
    'authDomain': getArgumentValue(arguments, '${prefix}authDomain') ?? '',
    'projectId': getArgumentValue(arguments, '${prefix}projectId') ?? '',
    'storageBucket':
        getArgumentValue(arguments, '${prefix}storageBucket') ?? '',
    'messagingSenderId':
        getArgumentValue(arguments, '${prefix}messagingSenderId') ?? '',
    'appId': getArgumentValue(arguments, '${prefix}appId') ?? '',
    'measurementId':
        getArgumentValue(arguments, '${prefix}measurementId') ?? '',
  };
}

void updateFirebaseConfig(List<String> platforms, List<String> arguments) {
  final file = File(ensembleConfigFilePath);
  if (!file.existsSync()) {
    throw Exception('Config file not found.');
  }

  final platform = platforms.first;
  final keys = getFirebaseKeys(platform, arguments);

  String content = file.readAsStringSync();

  // Update only the firebase:$platform section
  content = content.replaceAllMapped(
    RegExp(r'#\s*firebase:\s*\n\s*#\s*web:', multiLine: true),
    (match) => '  firebase:\n    $platform:',
  );

  // Uncomment the Firebase accounts structure
  final accountLines = [
    '#\\s*accounts:',
    '#\\s*firebase:',
    '#\\s*$platform:',
  ];

  for (final line in accountLines) {
    content = content.replaceAllMapped(RegExp(line, multiLine: true), (match) {
      return match[0]!.replaceFirst('#', '');
    });
  }

  // Replace the placeholders with actual keys only within the $platform block
  keys.forEach((key, value) {
    if (value.isNotEmpty) {
      content = content.replaceAllMapped(
        RegExp(
          r'(firebase:\s*\n.*?' +
              platform +
              r':\s*\n.*?)(\b' +
              key +
              r':\s*).*?(\n|$)',
          multiLine: true,
          dotAll: true,
        ),
        (match) => '${match.group(1)}$key: "$value"${match.group(3)}',
      );
      content = content.replaceAllMapped(
        RegExp(r'#\s*' + key + r':\s*".*"', multiLine: true),
        (match) => match.group(0)!.replaceFirst('#', ''),
      );
    }
  });

  file.writeAsStringSync(content);
}

void addClasspathDependency(String dependency) {
  final file = File(androidBuildGradleFilePath);
  if (!file.existsSync()) {
    throw Exception('Android build file not found.');
  }

  String content = file.readAsStringSync();

  if (!content.contains(dependency)) {
    final buildscriptRegExp =
        RegExp(r'buildscript\s*{[\s\S]*?dependencies\s*{');
    final match = buildscriptRegExp.firstMatch(content);
    if (match != null) {
      final insertPosition = match.end;
      content = content.replaceRange(
          insertPosition, insertPosition, '\n        $dependency');
    }
  }

  // Save the updated content back to the file
  file.writeAsStringSync(content);
}

void addPluginDependency(String dependency) {
  final file = File(androidAppBuildGradleFilePath);
  if (!file.existsSync()) {
    throw Exception('Android app build file not found.');
  }

  String content = file.readAsStringSync();

  // Add the plugin dependency if it doesn't already exist
  if (!content.contains(dependency)) {
    content = content.replaceFirst(
      RegExp(r"apply\s*plugin:\s*'com\.android\.application'"),
      'apply plugin: \'com.android.application\'\n$dependency',
    );
  }

  file.writeAsStringSync(content);
}

void addImplementationDependency(String dependency) {
  final file = File(androidAppBuildGradleFilePath);
  if (!file.existsSync()) {
    throw Exception('Android app build file not found.');
  }

  String content = file.readAsStringSync();

  // Add the implementation dependency if it doesn't already exist
  if (!content.contains(dependency)) {
    final dependenciesRegExp = RegExp(r'dependencies\s*{');
    final match = dependenciesRegExp.firstMatch(content);
    if (match != null) {
      final insertPosition = match.end;
      content = content.replaceRange(
          insertPosition, insertPosition, '\n    $dependency');
    }
  }

  file.writeAsStringSync(content);
}

void addSettingsPluginDependency(String dependency) {
  final file = File(androidSettingsGradleFilePath);
  if (!file.existsSync()) {
    throw Exception('Android settings file not found.');
  }

  String content = file.readAsStringSync();

  // Check if the dependency is already included in the plugins block
  if (!content.contains(dependency)) {
    int insertPosition = content.indexOf('plugins {');
    int endPosition = content.indexOf('}', insertPosition);
    content = content.substring(0, endPosition) +
        '\n    $dependency\n' +
        content.substring(endPosition);

    file.writeAsStringSync(content);
  }
}
