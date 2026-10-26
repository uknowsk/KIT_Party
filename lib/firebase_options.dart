// Firebase 프로젝트 "kit-party" 연결 정보 (android/app/google-services.json과 같은 값).
// 안드로이드에서만 실제 모드로 켜지고, 웹 미리보기는 체험 모드로 켜져요.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => null,
    };
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyD0xJ75UZE_QJW6F_kAjgrqKSN_Tq-2FWI',
    appId: '1:754325745907:android:2fd0cda4f9b280133cc786',
    messagingSenderId: '754325745907',
    projectId: 'kit-party',
    storageBucket: 'kit-party.firebasestorage.app',
  );

  /// 구글 로그인에 쓰는 웹 클라이언트 ID (google-services.json의 client_type 3).
  static const googleServerClientId =
      '754325745907-jpptbj2d50t0prcnuc6jnjv41sfcukqs.apps.googleusercontent.com';
}
