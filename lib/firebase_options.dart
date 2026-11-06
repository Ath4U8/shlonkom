import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      default: return android;
    }
  }
  static const FirebaseOptions web = FirebaseOptions(apiKey: 'AIzaSyDUMMY-WEB-KEY', appId: '1:123456789:web:abcdef', messagingSenderId: '123456789', projectId: 'shlonkom-a67c9', authDomain: 'shlonkom-a67c9.firebaseapp.com', storageBucket: 'shlonkom-a67c9.appspot.com');
  static const FirebaseOptions android = FirebaseOptions(apiKey: 'AIzaSyDUMMY-ANDROID-KEY', appId: '1:123456789:android:abcdef', messagingSenderId: '123456789', projectId: 'shlonkom-a67c9', storageBucket: 'shlonkom-a67c9.appspot.com');
  static const FirebaseOptions ios = FirebaseOptions(apiKey: 'AIzaSyDUMMY-IOS-KEY', appId: '1:123456789:ios:abcdef', messagingSenderId: '123456789', projectId: 'shlonkom-a67c9', storageBucket: 'shlonkom-a67c9.appspot.com', iosBundleId: 'com.shlonkom.app');
}
