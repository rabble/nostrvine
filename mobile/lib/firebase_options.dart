// ABOUTME: Per-platform Firebase options consumed by Firebase.initializeApp.
// ABOUTME: Supported platforms + project config: docs/CRASH_REPORTING_SETUP.md.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return kDebugMode ? androidStaging : android;
      case TargetPlatform.iOS:
        return kDebugMode ? iosStaging : ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
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
    apiKey: 'placeholder-api-key',
    appId: '1:placeholder:web:placeholder',
    messagingSenderId: 'placeholder-sender-id',
    projectId: 'openvine-placeholder',
    authDomain: 'openvine-placeholder.firebaseapp.com',
    storageBucket: 'openvine-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBUMlaHAMKqeS62WG7w4PeqBPRLMDIZCdo',
    appId: '1:972941478875:android:c716006682f92d9444b5fe',
    messagingSenderId: '972941478875',
    projectId: 'openvine-co',
    storageBucket: 'openvine-co.firebasestorage.app',
  );

  static const FirebaseOptions androidStaging = FirebaseOptions(
    apiKey: 'AIzaSyBUMlaHAMKqeS62WG7w4PeqBPRLMDIZCdo',
    appId: '1:972941478875:android:56ca239b8c04ca6044b5fe',
    messagingSenderId: '972941478875',
    projectId: 'openvine-co',
    storageBucket: 'openvine-co.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyChiPGndRdZwsMoLqnel2WSocROmoKLdB4',
    appId: '1:972941478875:ios:f61272b3cf485df244b5fe',
    messagingSenderId: '972941478875',
    projectId: 'openvine-co',
    storageBucket: 'openvine-co.firebasestorage.app',
    iosBundleId: 'co.openvine.app',
  );

  static const FirebaseOptions iosStaging = FirebaseOptions(
    apiKey: 'AIzaSyChiPGndRdZwsMoLqnel2WSocROmoKLdB4',
    appId: '1:972941478875:ios:2e044bbc68923a1844b5fe',
    messagingSenderId: '972941478875',
    projectId: 'openvine-co',
    storageBucket: 'openvine-co.firebasestorage.app',
    iosBundleId: 'co.openvine.app.staging',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyChiPGndRdZwsMoLqnel2WSocROmoKLdB4',
    appId: '1:972941478875:ios:f61272b3cf485df244b5fe',
    messagingSenderId: '972941478875',
    projectId: 'openvine-co',
    storageBucket: 'openvine-co.firebasestorage.app',
    iosBundleId: 'co.openvine.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'placeholder-api-key',
    appId: '1:placeholder:web:placeholder',
    messagingSenderId: 'placeholder-sender-id',
    projectId: 'openvine-placeholder',
    authDomain: 'openvine-placeholder.firebaseapp.com',
    storageBucket: 'openvine-placeholder.appspot.com',
  );
}
