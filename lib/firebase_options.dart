// File: lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDTSQK6ZAkEzcIww00psqb3kL3xZzLtmIA",
    appId: "1:195880451791:web:ecadf9a81437e1db23c1ba",
    messagingSenderId: "195880451791",
    projectId: "workstudy-bcda5",
    authDomain: "workstudy-bcda5.firebaseapp.com",
    storageBucket: "workstudy-bcda5.firebasestorage.app",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDTSQK6ZAkEzcIww00psqb3kL3xZzLtmIA",
    appId: "1:195880451791:android:ecadf9a81437e1db23c1ba",
    messagingSenderId: "195880451791",
    projectId: "workstudy-bcda5",
    storageBucket: "workstudy-bcda5.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyDTSQK6ZAkEzcIww00psqb3kL3xZzLtmIA",
    appId: "1:195880451791:ios:ecadf9a81437e1db23c1ba",
    messagingSenderId: "195880451791",
    projectId: "workstudy-bcda5",
    storageBucket: "workstudy-bcda5.firebasestorage.app",
    iosBundleId: "com.example.workstudy",
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "AIzaSyDTSQK6ZAkEzcIww00psqb3kL3xZzLtmIA",
    appId: "1:195880451791:ios:ecadf9a81437e1db23c1ba",
    messagingSenderId: "195880451791",
    projectId: "workstudy-bcda5",
    storageBucket: "workstudy-bcda5.firebasestorage.app",
    iosBundleId: "com.example.workstudy",
  );
}
