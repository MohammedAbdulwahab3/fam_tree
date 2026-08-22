// This is a demo/mock Firebase configuration
// In production, generate this using FlutterFire CLI: flutterfire configure

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCP1pUXLjbmD63ii3OHWJ7aZWAMBMZe1Pw',
    appId: '1:216305526466:web:5d33476eed970ff4debd5b',
    messagingSenderId: '216305526466',
    projectId: 'family-tree-29547',
    authDomain: 'family-tree-29547.firebaseapp.com',
    storageBucket: 'family-tree-29547.firebasestorage.app',
    measurementId: 'G-KTHFRF3ZL2',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBMYIJW1Sr6oKTtln9Q4FY0JX6UST8PL7s',
    appId: '1:216305526466:android:3a0622bbd420e9c8debd5b',
    messagingSenderId: '216305526466',
    projectId: 'family-tree-29547',
    storageBucket: 'family-tree-29547.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC964jYp09SJxC_ePUPDzZIjBs1fif-g9c',
    appId: '1:216305526466:ios:002be27bad58241ddebd5b',
    messagingSenderId: '216305526466',
    projectId: 'family-tree-29547',
    storageBucket: 'family-tree-29547.firebasestorage.app',
    iosBundleId: 'com.familytree.familyTree',
  );

}