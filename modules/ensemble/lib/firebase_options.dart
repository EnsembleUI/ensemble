import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyC-YeNdc9IRMQpuxxVB27UkUIv9KcfpRVg",
    authDomain: "ensemble-web-studio.firebaseapp.com",
    databaseURL: "https://ensemble-web-studio-default-rtdb.firebaseio.com",
    projectId: "ensemble-web-studio",
    storageBucket: "ensemble-web-studio.appspot.com",
    messagingSenderId: "326748243798",
    appId: "1:326748243798:web:3bf6a44d0d61123994b8f7",
    measurementId: "G-CQGG9T6GNP",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCUCmUd2Dh-pw_D4k869Dx62QGUkgNhkIg',
    appId: '1:326748243798:android:7b2979a8fdc1085594b8f7',
    messagingSenderId: '326748243798',
    projectId: 'ensemble-web-studio',
    storageBucket: 'ensemble-web-studio.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDjd87VEZhj0Kf_jAxvBKt-s-VX5LZU-1g',
    appId: '1:326748243798:ios:30f2a4f824dc58ea94b8f7',
    messagingSenderId: '326748243798',
    projectId: 'ensemble-web-studio',
    storageBucket: 'ensemble-web-studio.appspot.com',
    iosClientId:
        '326748243798-f5n6p87r6optmgkgpblb6a8mhh7efimg.apps.googleusercontent.com',
  );
}
