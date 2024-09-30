import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

  bool success = true;

  // Define the contacts module statements
  final contactsStatements = {
    'importStatements': [
      {
        'statement': "import 'package:ensemble_contacts/contact_manager.dart';",
        'regex': toRegexPattern(
            "import 'package:ensemble_contacts/contact_manager.dart';"),
      }
    ],
    'registerStatements': [
      {
        'statement':
            'GetIt.I.registerSingleton<ContactManager>(ContactManagerImpl());',
        'regex': toRegexPattern(
            'GetIt.I.registerSingleton<ContactManager>(ContactManagerImpl());'),
      }
    ],
    'useStatements': [
      {
        'statement': 'static const useContacts = true;',
        'regex':
            toRegexPattern('static const useContacts = true;', isBoolean: true),
      }
    ],
    'pubspecDependencies': [
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
    ],
  };

  // Define Android and iOS permissions for the contacts
  final androidPermissions = [
    '<uses-permission android:name="android.permission.READ_CONTACTS"/>',
    '<uses-permission android:name="android.permission.WRITE_CONTACTS"/>',
  ];

  final iOSPermissions = [
    {
      'paramKey': '--contacts_description',
      'key': 'NSContactsUsageDescription',
    }
  ];

  // Update the ensemble_modules.dart file
  try {
    updateEnsembleModules(
        ensembleModulesFilePath,
        contactsStatements['importStatements']!,
        contactsStatements['registerStatements']!,
        contactsStatements['useStatements']!);
  } catch (e) {
    print(e);
    success = false;
  }

  // Update the pubspec.yaml file
  try {
    updatePubspec(pubspecFilePath, contactsStatements['pubspecDependencies']!);
  } catch (e) {
    print(e);
    success = false;
  }

  // Add the contacts permissions to AndroidManifest.xml
  if (platforms.contains('android')) {
    try {
      updateAndroidPermissions(androidManifestFilePath, androidPermissions);
    } catch (e) {
      print('Error updating AndroidManifest.xml: $e');
      success = false;
    }
  }

  // Add the contacts usage description to the iOS Info.plist file
  if (platforms.contains('ios')) {
    try {
      updateIOSPermissions(iosInfoPlistFilePath, iOSPermissions, arguments);
    } catch (e) {
      print('Error updating Info.plist: $e');
      success = false;
    }
  }

  if (success) {
    print(
        'Contacts module enabled successfully for ${platforms.join(', ')}! 🎉');
  }
}
