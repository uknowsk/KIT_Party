// Firebase 프로젝트를 만든 뒤 `flutterfire configure` 명령이 이 파일을 새로 만들어요.
// 그 전까지는 null이라서 앱이 체험 모드(시트 데이터)로 켜집니다.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform => null;
}
