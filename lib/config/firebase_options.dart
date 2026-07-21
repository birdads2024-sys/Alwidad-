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
        return ios;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAi7rY58R_A7MEEiLM1FWOaloOQQ4sbnqg',
    appId: '1:779049231491:ios:e5e2ad89b2032dc101e7b6',
    messagingSenderId: '779049231491',
    projectId: 'alwidad-c4312',
    storageBucket: 'alwidad-c4312.firebasestorage.app',
    iosBundleId: 'com.alwidad.app',
  );

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
