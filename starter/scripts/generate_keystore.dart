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

    // Ensure passwords are at least 6 characters long to avoid issues with keytool
    if (storePassword.length < 6 || keyPassword.length < 6) {
      throw Exception(
          'storePassword and keyPassword must be at least 6 characters long.');
    }

    // Define paths for the keystore and key.properties files
    String androidAppDir = Directory.current.path + '/android/app';
    String androidDir = Directory.current.path + '/android';
    String keystorePath = '$androidAppDir/keystore.jks';
    String keyPropertiesPath = '$androidDir/key.properties';

    // Check if the keystore file already exists
    if (File(keystorePath).existsSync()) {
      print('Keystore already exists at $keystorePath');
      exit(0);
    }

    // Ensure that the directories exist
    Directory(androidAppDir).createSync(recursive: true);
    Directory(androidDir).createSync(recursive: true);

    // Generate the keystore using the keytool command
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

    if (result.exitCode != 0) {
      throw Exception(
          'Error generating keystore. Exit code: ${result.exitCode}\nError: ${result.stderr}');
    }

    print(result.stdout);

    // Create the key.properties file with the keystore configuration
    String keyPropertiesContent = '''
storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=$keyAlias
storeFile=keystore.jks
''';

    File keyPropertiesFile = File(keyPropertiesPath);
    keyPropertiesFile.writeAsStringSync(keyPropertiesContent.trim());

    print('Keystore generated successfully!');
  } catch (e) {
    stderr.writeln('An error occurred: $e');
    exit(1);
  }
}
