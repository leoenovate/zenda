import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // Add other platforms if needed
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCSPqAFTnwCUkLUgMgYxnKWd6p5wRsv4Lg',
    appId: '1:704481190555:web:34a2d2515f542995a55c3e',
    messagingSenderId: '704481190555',
    projectId: 'enovate-zenda',
    authDomain: 'enovate-zenda.firebaseapp.com',
    storageBucket: 'enovate-zenda.firebasestorage.app',
    measurementId: 'G-CS5V2KYLMX',
  );
} 