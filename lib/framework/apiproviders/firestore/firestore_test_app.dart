import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ensemble/framework/apiproviders/firestore/firestore_app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';


const firebaseConfig = {
  "web": {
    "apiKey": "AIzaSyAd-VSCqozXsd1FCH4UJy1DxgzTutqPJ2g",
    "appId": "1:651616418101:web:978fe504871941a39cb47c",
    "messagingSenderId": "651616418101",
    "projectId": "khurram-firebase-integration",
    "authDomain": "khurram-firebase-integration.firebaseapp.com",
    "storageBucket": "khurram-firebase-integration.appspot.com",
    "measurementId": "G-XTKJM33SCZ"
  },
  "android": {
    "apiKey": "AIzaSyAALIZ7Ee4DzF_ot2WP6bBnLsR_oAyuUpw",
    "appId": "1:651616418101:android:4112d059a591fc8d9cb47c",
    "messagingSenderId": "651616418101",
    "projectId": "khurram-firebase-integration",
    "storageBucket": "khurram-firebase-integration.appspot.com"
  },
  "ios": {
    "apiKey": "AIzaSyC8fJsYh-SnxCKycsHWU6PmemWxOHi4Os0",
    "appId": "1:651616418101:ios:826578cfd5a891739cb47c",
    "messagingSenderId": "651616418101",
    "projectId": "khurram-firebase-integration",
    "storageBucket": "khurram-firebase-integration.appspot.com",
    "iosBundleId": "com.khurram.firebaseTest"
  }
};

Map<String, FirebaseOptions> initFirebaseOptions(Map<String, dynamic> config) {
  Map<String, FirebaseOptions> options = {};

  config.forEach((key, value) {
    options[key] = FirebaseOptions(
      apiKey: value['apiKey'],
      appId: value['appId'],
      messagingSenderId: value['messagingSenderId'],
      projectId: value['projectId'],
      authDomain: value.containsKey('authDomain') ? value['authDomain'] : null,
      storageBucket: value.containsKey('storageBucket') ? value['storageBucket'] : null,
      measurementId: value.containsKey('measurementId') ? value['measurementId'] : null,
      iosBundleId: value.containsKey('iosBundleId') ? value['iosBundleId'] : null,
    );
  });

  return options;
}

FirebaseOptions getCurrentPlatformFirebaseOptions(Map<String, FirebaseOptions> options) {
  if (kIsWeb) {
    return options['web']!;
  } else if (Platform.isAndroid) {
    return options['android']!;
  } else if (Platform.isIOS) {
    return options['ios']!;
  } else {
    throw UnsupportedError('Your platform is not supported for Firebase Initialization.');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: Initialize FirebaseOptions
  Map<String, FirebaseOptions> firebaseOptions = initFirebaseOptions(firebaseConfig);

  // Step 2: Get the FirebaseOptions for the current platform
  FirebaseOptions currentPlatformOptions = getCurrentPlatformFirebaseOptions(firebaseOptions);

  // Initialize Firebase with the selected options
  FirebaseApp app = await Firebase.initializeApp(options: currentPlatformOptions);
  FirestoreApp firestore = FirestoreApp(FirebaseFirestore.instanceFor(app: app));
  // await generateTestData(firestore);
  //
  // print('Test data generation complete.');
  await testUpdateOperation(firestore);
  await testDeleteOperation(firestore);

  await testArrayContainsQuery(firestore);
  await testOrderByAndLimitQuery(firestore);
  await testMultipleWhereQuery(firestore);
  await testCollectionGroupQueryForTeamsWithPerformGetOperation(firestore);
  print('All query tests completed.');
}

Future<void> generateTestData(FirestoreApp apiProvider) async {
  final List<String> venues = ['Venue A', 'Venue B', 'Venue C', 'Venue D', 'Venue E'];
  final List<List<String>> teams = List.generate(30, (index) => ['Team ${index * 2 + 1}', 'Team ${index * 2 + 2}']);
  final List<String> eventNames = ['Goal', 'Red Card', 'Yellow Card', 'Injury', 'Timeout'];

  print('Starting test data generation...');

  for (int i = 1; i < 5; i++) {
    String competitionName = 'Competition ${i + 1}';
    String competitionId = 'comp_${i + 1}';

    print('Creating competition: $competitionName with ID: $competitionId');
    await apiProvider.performSetOperation({
      'path': 'sports/soccer/competitions/$competitionId',
      'data': {'name': competitionName, 'id': competitionId},
    });

    for (int j = 0; j < 10; j++) {
      List<String> matchTeams = teams[Random().nextInt(teams.length)];
      String matchVenue = venues[Random().nextInt(venues.length)];
      DateTime matchTime = DateTime.now().add(Duration(days: Random().nextInt(365)));

      DocumentReference matchRef = await apiProvider.performAddOperation({
        'path': 'sports/soccer/competitions/$competitionId/matches',
        'data': {
          'teams': matchTeams,
          'venue': matchVenue,
          'matchTime': matchTime,
        },
      });

      int eventsCount = Random().nextInt(1) + 10; // Generating between 100 and 1000 events
      for (int k = 0; k < eventsCount; k++) {
        String eventName = eventNames[Random().nextInt(eventNames.length)];
        String teamInvolved = matchTeams[Random().nextInt(matchTeams.length)];
        Map<String, dynamic> payload = {
          "time": "${Random().nextInt(90) + 1}",
          "team": teamInvolved,
          "player": "Player ${Random().nextInt(22) + 1}",
          "eventType": eventName,
          "details": jsonEncode({
            "assist": "Player ${Random().nextInt(22) + 1}",
            "partOfPlay": "Open Play",
            "distance": "${Random().nextInt(30) + 5} meters",
            "goalType": "Right-footed shot"
          }),
        };

        await apiProvider.performAddOperation({
          'path': 'sports/soccer/competitions/$competitionId/matches/${matchRef.id}/events',
          'data': {
            'name': eventName,
            'payload': payload,
          },
        });
      }

       // Print progress every 100 matches
        print('Match $j created for competition: $competitionName with ${eventsCount} events');

    }
    print('Finished creating matches for competition: $competitionName');
  }
  print('Test data generation complete.');
}

Future<void> testUpdateOperation(FirestoreApp apiProvider) async {
  String competitionId = 'comp_1'; // Example for one competition
  String matchPath = 'sports/soccer/competitions/$competitionId/matches/8c1UXnBgNupqfFVeK7U6';

  // Fetch the match before update
  dynamic beforeUpdateSnapshot = await apiProvider.performGetOperation({
    'path': matchPath,
  });
  var beforeUpdateData = (beforeUpdateSnapshot as DocumentSnapshot).data() as Map<String, dynamic>;
  print('Venue before update: ${beforeUpdateData['venue']}');

  String time = DateTime.now().toString();
  // Perform the update
  await apiProvider.performUpdateOperation({
    'path': matchPath,
    'data': {'venue': 'Updated Venue: $time'},
  });

  // Fetch the match after update
  dynamic afterUpdateSnapshot = await apiProvider.performGetOperation({
    'path': matchPath,
  });
  var afterUpdateData = (afterUpdateSnapshot as DocumentSnapshot).data() as Map<String, dynamic>;
  print('Venue after update: ${afterUpdateData['venue']}');

  // Validation
  if (afterUpdateData['venue'] == 'Updated Venue: $time') {
    print('Update validation successful.');
  } else {
    print('Update validation failed.');
  }
}
Future<void> testDeleteOperation(FirestoreApp apiProvider) async {
  String competitionId = 'comp_2'; // Example for one competition
  String matchId = 'UJzdR6ozKzKq8R2SZ5eh';
  String eventId = 'BG0yxqMGcT7KzJDvwo9l';
  String eventPath = 'sports/soccer/competitions/$competitionId/matches/$matchId/events/$eventId';

  // Verify the event exists before deletion
  dynamic beforeDeleteSnapshot = await apiProvider.performGetOperation({
    'path': 'sports/soccer/competitions/$competitionId/matches/$matchId/events/$eventId'
  });

  if (beforeDeleteSnapshot == null || !(beforeDeleteSnapshot as DocumentSnapshot).exists){
    print('Event already does not exist.');
    return;
  }

  // Perform the delete operation
  await apiProvider.performDeleteOperation({'path': eventPath});

  // Verify the event does not exist after deletion
  dynamic afterDeleteSnapshot = await apiProvider.performGetOperation({
    'path': 'sports/soccer/competitions/$competitionId/matches/$matchId/events/$eventId',
  });

  // Validation
  if (afterDeleteSnapshot == null || !(afterDeleteSnapshot as DocumentSnapshot).exists) {
    print('Delete validation successful.');
  } else {
    print('Delete validation failed.');
  }
}
Future<void> testArrayContainsQuery(FirestoreApp apiProvider) async {
  Map evaluatedApi = {
    'path': 'sports/soccer/competitions/comp_1/matches',
    'query': {
      'where': [
        {
          'field': 'teams',
          'operator': 'array-contains',
          'value': 'Germany',
        },
      ],
    },
  };

  var results = await apiProvider.performGetOperation(evaluatedApi);
  print("Test Array Contains Query: Found ${results.docs.length} matches with Germany.");
}
Future<void> testOrderByAndLimitQuery(FirestoreApp apiProvider) async {
  Map evaluatedApi = {
    'path': 'sports/soccer/competitions/comp_1/matches',
    'query': {
      'orderBy': [
        'matchTime',
      ],
      'limit': 5,
    },
  };

  var results = await apiProvider.performGetOperation(evaluatedApi);
  print("Test OrderBy and Limit Query: Found ${results.docs.length} matches, ordered by matchTime.");
}
Future<void> testMultipleWhereQuery(FirestoreApp apiProvider) async {
  Map evaluatedApi = {
    'path': 'sports/soccer/competitions/comp_1/matches',
    'query': {
      'where': [
        {
          'field': 'venue',
          'operator': '==',
          'value': 'Berlin Stadium',
        },
        {
          'field': 'teams',
          'operator': 'array-contains',
          'value': 'Germany',
        },
      ],
    },
  };

  var results = await apiProvider.performGetOperation(evaluatedApi);
  print("Test Multiple Where Query: Found ${results.docs.length} matches in Berlin Stadium with Germany.");
}

Future<void> testCollectionGroupQueryForTeamsWithPerformGetOperation(FirestoreApp apiProvider) async {
  Map queryMap = {
    'path': 'matches',
    'isCollectionGroup': true,
    'query': {
      'where': [
        {
          'field': 'teams',
          'operator': 'array-contains-any',
          'value': ['Team 23', 'Team 24', 'germany', 'Netherlands'],
        },
      ],
    },
  };

  var querySnapshot = await apiProvider.performGetOperation(queryMap);

  // Assuming querySnapshot is correctly typed as QuerySnapshot or has a similar structure
  print('Found ${querySnapshot.docs.length} matches with Team 23 or Team 24');
  for (var doc in querySnapshot.docs) {
    print(doc.data()); // Adjust based on how you wish to output or use the document data
  }
}







