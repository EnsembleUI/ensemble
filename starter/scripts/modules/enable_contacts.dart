import 'dart:io';
import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

  final contactsStatements = {
    'moduleStatements': [
      "import 'package:ensemble_contacts/contact_manager.dart';",
      "GetIt.I.registerSingleton<ContactManager>(ContactManagerImpl());"
    ],
    'useStatements': ["static const useContacts = true;"],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_contacts:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/contacts
''',
      'regex':
          r'#\s*ensemble_contacts:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/contacts',
    }
  ];

  final androidPermissions = [
    '<uses-permission android:name="android.permission.READ_CONTACTS"/>',
    '<uses-permission android:name="android.permission.WRITE_CONTACTS"/>',
  ];

  final iOSPermissions = [
    {
      'key': '--contacts_description',
      'value': 'NSContactsUsageDescription',
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      ensembleModulesFilePath,
      contactsStatements['moduleStatements']!,
      contactsStatements['useStatements']!,
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecFilePath, pubspecDependencies);

    // Add the contacts permissions to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(androidManifestFilePath, androidPermissions);
    }

    // Add the contacts usage description to the iOS Info.plist file
    if (platforms.contains('ios')) {
      updateIOSPermissions(iosInfoPlistFilePath, iOSPermissions, arguments);
    }

    print(
        'Contacts module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}