import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for ${defaultTargetPlatform.toString()}',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCSPqAFTnwCUkLUgMgYxnKWd6p5wRsv4Lg',
    appId: '1:704481190555:web:34a2d2515f542995a55c3e',
    messagingSenderId: '704481190555',
    projectId: 'enovate-zenda',
    authDomain: 'enovate-zenda.firebaseapp.com',
    storageBucket: 'enovate-zenda.appspot.com',
    measurementId: 'G-CS5V2KYLMX',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCSPqAFTnwCUkLUgMgYxnKWd6p5wRsv4Lg',
    appId: '1:704481190555:android:34a2d2515f542995a55c3e',
    messagingSenderId: '704481190555',
    projectId: 'enovate-zenda',
    storageBucket: 'enovate-zenda.appspot.com',
  );
  
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCSPqAFTnwCUkLUgMgYxnKWd6p5wRsv4Lg',
    appId: '1:704481190555:ios:34a2d2515f542995a55c3e',
    messagingSenderId: '704481190555',
    projectId: 'enovate-zenda',
    storageBucket: 'enovate-zenda.appspot.com',
    iosBundleId: 'com.example.ucc',
  );
  
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCSPqAFTnwCUkLUgMgYxnKWd6p5wRsv4Lg',
    appId: '1:704481190555:macos:34a2d2515f542995a55c3e',
    messagingSenderId: '704481190555',
    projectId: 'enovate-zenda',
    storageBucket: 'enovate-zenda.appspot.com',
    iosBundleId: 'com.example.ucc.RunnerTests',
  );
  
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCSPqAFTnwCUkLUgMgYxnKWd6p5wRsv4Lg',
    appId: '1:704481190555:windows:34a2d2515f542995a55c3e',
    messagingSenderId: '704481190555',
    projectId: 'enovate-zenda',
    storageBucket: 'enovate-zenda.appspot.com',
  );
  
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyCSPqAFTnwCUkLUgMgYxnKWd6p5wRsv4Lg',
    appId: '1:704481190555:linux:34a2d2515f542995a55c3e',
    messagingSenderId: '704481190555',
    projectId: 'enovate-zenda',
    storageBucket: 'enovate-zenda.appspot.com',
  );
} 