import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

/// 구글 계정으로 로그인.
class AuthService {
  static bool _ready = false;

  static Future<User?> signInWithGoogle() async {
    if (!_ready) {
      await GoogleSignIn.instance.initialize(serverClientId: DefaultFirebaseOptions.googleServerClientId);
      _ready = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    final cred = GoogleAuthProvider.credential(idToken: idToken);
    return (await FirebaseAuth.instance.signInWithCredential(cred)).user;
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    if (_ready) await GoogleSignIn.instance.signOut();
  }
}
