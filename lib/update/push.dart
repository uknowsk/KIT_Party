import 'package:firebase_messaging/firebase_messaging.dart';

/// 새 버전 푸시 알림. 앱이 꺼져 있을 때 오면 폰이 알림을 띄우고
/// 앱 아이콘에 뱃지(점이나 숫자)를 붙여줘요.
class UpdatePush {
  static const topic = 'updates';

  static bool _isUpdate(RemoteMessage m) => m.data['type'] == 'update';

  /// [onUpdate]: 업데이트 알림을 눌렀거나, 앱을 보고 있는 중에 알림이 왔을 때.
  static Future<void> init(void Function() onUpdate) async {
    final fm = FirebaseMessaging.instance;
    try {
      // 안드로이드 13부터는 "알림 허용할까요?"를 한 번 물어봐요.
      await fm.requestPermission();
      await fm.subscribeToTopic(topic);
    } catch (_) {
      // 구글 서비스가 없는 폰 등. 앱을 열 때 확인하는 걸로 충분해요.
    }
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (_isUpdate(m)) onUpdate();
    });
    FirebaseMessaging.onMessage.listen((m) {
      if (_isUpdate(m)) onUpdate();
    });
    final first = await fm.getInitialMessage();
    if (first != null && _isUpdate(first)) onUpdate();
  }
}
