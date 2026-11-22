import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'card_parser.dart';

/// 폰의 카드 결제 문자·알림을 가져와요 (안드로이드만).
/// 모든 내용은 폰 안에서만 읽고, 총무가 '저장'한 것만 장부에 올라가요.
class CardInbox {
  static const _ch = MethodChannel('kit_party/cards');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<T?> _call<T>(String m, [Map<String, Object?>? args]) async {
    if (!supported) return null;
    try {
      return await _ch.invokeMethod<T>(m, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> smsGranted() async => await _call<bool>('smsGranted') ?? false;
  static Future<bool> requestSms() async => await _call<bool>('requestSms') ?? false;
  static Future<bool> notiEnabled() async => await _call<bool>('notiEnabled') ?? false;
  static Future<void> openNotiSettings() => _call('openNotiSettings');
  static Future<void> openAppSettings() => _call('openAppSettings');

  /// [from]~[to] 사이에 온 카드 결제를 문자 + 앱 알림에서 모아요. 같은 결제는 한 번만.
  static Future<List<CardCharge>> load(DateTime from, DateTime to) async {
    final out = <CardCharge>[];
    final sms = await _call<List>('readSms', {
          'from': from.millisecondsSinceEpoch,
          'to': to.millisecondsSinceEpoch,
        }) ??
        const [];
    for (final m in sms) {
      final map = Map<String, Object?>.from(m as Map);
      final c = parseCardMessage(
        '${map['body']}',
        received: DateTime.fromMillisecondsSinceEpoch((map['date'] as num).toInt()),
      );
      if (c != null) out.add(c);
    }
    final noti = await _call<List>('readNoti') ?? const [];
    for (final m in noti) {
      final map = Map<String, Object?>.from(m as Map);
      final at = DateTime.fromMillisecondsSinceEpoch((map['date'] as num).toInt());
      if (at.isBefore(from) || at.isAfter(to)) continue;
      final c = parseCardMessage(
        '${map['text']}',
        received: at,
        issuerHint: packageIssuers['${map['pkg']}'],
        source: 'noti',
      );
      if (c == null) continue;
      // 문자로도 온 결제면 문자 쪽을 써요 (카드번호가 더 정확해요).
      if (out.any((o) => o.sameAs(c))) continue;
      out.add(c);
    }
    out.sort((a, b) => b.time.compareTo(a.time));
    return out;
  }

  // ── 폰에만 저장하는 작은 설정 ──
  static Future<Set<String>> _getSet(String key) async {
    final s = await _call<String>('getPref', {'key': key});
    if (s == null) return {};
    try {
      return {for (final v in jsonDecode(s) as List) '$v'};
    } catch (_) {
      return {};
    }
  }

  static Future<void> _setSet(String key, Set<String> v) => _call('setPref', {'key': key, 'value': jsonEncode(v.toList())});

  /// 장부에 올릴 카드 (비어 있으면 전부).
  static Future<Set<String>> chosenCards() => _getSet('cards');
  static Future<void> setChosenCards(Set<String> v) => _setSet('cards', v);

  /// 이미 장부에 올렸거나 '숨기기' 한 결제.
  static Future<Set<String>> handled() => _getSet('handled');
  static Future<void> markHandled(Iterable<String> keys) async {
    final s = await handled();
    s.addAll(keys);
    // 너무 커지지 않게 최근 1000개만
    final list = s.toList();
    await _setSet('handled', list.length > 1000 ? list.sublist(list.length - 1000).toSet() : s);
  }

  static Future<void> unmarkHandled(String key) async {
    final s = await handled();
    s.remove(key);
    await _setSet('handled', s);
  }
}
