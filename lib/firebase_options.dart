// Jalur cadangan modul: nilai disalin manual dari Firebase Console >
// Project settings > aplikasi web. Pengenal project, bukan password.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  // shortcut: hanya web (target wajib Chrome); jalankan `flutterfire configure` bila butuh Android.
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB_GEL7Ewg-Ig-70jlSZeO3SO7ryzH39Q0',
    appId: '1:917680675165:web:f616cf564e2bc542aef0b4',
    messagingSenderId: '917680675165',
    projectId: 'mygarage-b7458',
    authDomain: 'mygarage-b7458.firebaseapp.com',
    storageBucket: 'mygarage-b7458.firebasestorage.app',
  );
}
