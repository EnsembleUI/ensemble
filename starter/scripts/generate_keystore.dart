import 'dart:io';
import 'utils.dart';

void main(List<String> arguments) async {
  try {
    // Parse the arguments
    String? storePassword = getArgumentValue(arguments, 'storePassword');
    String? keyPassword = getArgumentValue(arguments, 'keyPassword');
    String? keyAlias = getArgumentValue(arguments, 'keyAlias');

    if (storePassword == null || keyPassword == null || keyAlias == null) {
      throw Exception(
          'Missing required arguments. Usage: npm run generate_keystore storePassword=<password> keyPassword=<password> keyAlias=<alias>');
    }

    String androidAppDir = Directory.current.path + '/android/app';
    String androidDir = Directory.current.path + '/android';
    String keystorePath = '$androidAppDir/keystore.jks';
    String keyPropertiesPath = '$androidDir/key.properties';

    if (File(keystorePath).existsSync()) {
      print('Keystore already exists');
    } else {
      Directory(androidAppDir).createSync(recursive: true);
      Directory(androidDir).createSync(recursive: true);

      String command = 'keytool';
      List<String> args = [
        '-genkey',
        '-v',
        '-keystore',
        keystorePath,
        '-alias',
        keyAlias,
        '-keyalg',
        'RSA',
        '-keysize',
        '2048',
        '-validity',
        '9125',
        '-storepass',
        storePassword,
        '-keypass',
        keyPassword,
        '-dname',
        'CN=Unknown, OU=Unknown, O=Unknown, L=Unknown, S=Unknown, C=US'
      ];

      ProcessResult result = await Process.run(command, args);
      print('keystore generated successfully!');

      if (result.exitCode != 0) {
        throw Exception('Error generating keystore: ${result.stderr}');
      }

      print(result.stdout);
    }

    // Check if key.properties exists, if not, create it
    if (!File(keyPropertiesPath).existsSync()) {
      String keyPropertiesContent = '''
storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=$keyAlias
storeFile=keystore.jks
''';

      File keyPropertiesFile = File(keyPropertiesPath);
      keyPropertiesFile.writeAsStringSync(keyPropertiesContent.trim());

      print('key.properties file created successfully!');
    } else {
      print('key.properties file already exists');
    }
  } catch (e) {
    stderr.writeln('An error occurred: $e');
    exit(1);
  }
}
