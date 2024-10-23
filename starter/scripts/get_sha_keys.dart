import 'dart:io';

void main(List<String> arguments) async {
  try {
    String keystorePath = Directory.current.path + '/android/app/keystore.jks';
    String keyPropertiesPath =
        Directory.current.path + '/android/key.properties';
    String shaKeysFilePath = Directory.current.path + '/android/sha_keys.txt';

    // Ensure the keystore exists
    if (!File(keystorePath).existsSync()) {
      throw Exception(
          'Keystore not found, run `npm run generate_keystore` first');
    }

    if (!File(keyPropertiesPath).existsSync()) {
      throw Exception('key.properties file not found');
    }

    Map<String, String> keyProperties = {};
    List<String> lines = File(keyPropertiesPath).readAsLinesSync();
    for (var line in lines) {
      var parts = line.split('=');
      if (parts.length == 2) {
        keyProperties[parts[0]] = parts[1];
      }
    }

    if (!keyProperties.containsKey('storePassword') ||
        !keyProperties.containsKey('keyAlias')) {
      throw Exception('Missing storePassword or keyAlias in key.properties');
    }

    String storePassword = keyProperties['storePassword']!;
    String keyAlias = keyProperties['keyAlias']!;

    String command = 'keytool';
    List<String> shaArgs = [
      '-list',
      '-v',
      '-keystore',
      keystorePath,
      '-alias',
      keyAlias,
      '-storepass',
      storePassword
    ];

    ProcessResult shaResult = await Process.run(command, shaArgs);

    if (shaResult.exitCode != 0) {
      throw Exception('Failed to fetch SHA fingerprints: ${shaResult.stderr}');
    }

    File shaKeysFile = File(shaKeysFilePath);
    shaKeysFile.writeAsStringSync(shaResult.stdout);

    print('SHA keys saved successfully at /android/sha_keys.txt');
  } catch (e) {
    stderr.writeln('An error occurred: $e');
    exit(1);
  }
}
