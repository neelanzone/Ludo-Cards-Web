import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDHsAyBj2am-qyxT6_k9EsT9GKBfOPXXf8',
    appId: '1:1010777931239:web:62b5c56e349ae7c0a49142',
    messagingSenderId: '1010777931239',
    projectId: 'ludo-cards',
    authDomain: 'ludo-cards.firebaseapp.com',
    storageBucket: 'ludo-cards.firebasestorage.app',
    measurementId: 'G-58PMJ0TCHG',
  );

}