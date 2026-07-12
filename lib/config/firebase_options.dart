import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return null; // سيتم الاعتماد على ملف google-services.json
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBaLgGyC7ZlKuflIHFc-zeBXUxIm92CD3g',
    appId: '1:779049231491:web:905c434f8f22a19201e7b6',
    messagingSenderId: '779049231491',
    projectId: 'alwidad-c4312',
    authDomain: 'alwidad-c4312.firebaseapp.com',
    storageBucket: 'alwidad-c4312.firebasestorage.app',
    measurementId: 'G-JVC3CSW1WW',
  );
}
