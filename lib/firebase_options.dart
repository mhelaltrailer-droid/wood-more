// قالب مؤقت — استبدله بإعدادات مشروعك بتشغيل:
// dart pub global run flutterfire_cli:flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return FirebaseOptions(
      apiKey: 'YOUR_API_KEY',
      appId: 'YOUR_APP_ID',
      messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
      projectId: 'YOUR_PROJECT_ID',
      storageBucket: 'YOUR_PROJECT_ID.appspot.com',
      authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    );
  }
}
