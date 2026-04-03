import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Firebase yapılandırması — GoogleService-Info.plist değerlerinden üretildi.
/// flutterfire configure yerine elle oluşturuldu (yalnızca iOS).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: $defaultTargetPlatform desteklenmiyor.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDzN78BX_NBDjgTsl64wnTZrDdD9n3Dx-A',
    appId: '1:461986109206:ios:6094dd2d4efb626896a237',
    messagingSenderId: '461986109206',
    projectId: 'sleepora-89902',
    storageBucket: 'sleepora-89902.firebasestorage.app',
    iosBundleId: 'com.enginerdem.sleepora',
    iosClientId:
        '461986109206-por2v13868hqq5tqe0o3cgiaobepmbl3.apps.googleusercontent.com',
  );
}
