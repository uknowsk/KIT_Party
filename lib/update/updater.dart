import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'release.dart';

/// 새 버전 확인 → 내려받기 → 설치 화면 열기.
class Updater {
  static const _latestUrl = 'https://api.github.com/repos/uknowsk/KIT_Party/releases/latest';
  static const _channel = MethodChannel('kit_party/update');

  /// 지금 깔린 앱 버전. 예: 1.0.8
  static Future<String> currentVersion() async => (await PackageInfo.fromPlatform()).version;

  /// 가장 최근 릴리즈. 인터넷이 안 되면 null.
  static Future<ReleaseInfo?> latest() async {
    try {
      final r = await http
          .get(Uri.parse(_latestUrl), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      return ReleaseInfo.fromGitHub(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 지금보다 새 버전이 있으면 그 정보, 없으면 null.
  static Future<ReleaseInfo?> newer() async {
    final rel = await latest();
    if (rel == null) return null;
    final now = await currentVersion();
    return ReleaseInfo.compare(rel.version, now) > 0 ? rel : null;
  }

  /// APK를 앱 임시 폴더에 내려받아요. [onProgress]는 0~1.
  static Future<File> download(ReleaseInfo rel, void Function(double) onProgress) async {
    final dir = await _channel.invokeMethod<String>('updatesDir');
    final file = File('$dir/kit-party-${rel.version}.apk');
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(rel.apkUrl)));
      if (res.statusCode != 200) throw HttpException('내려받기 실패 (${res.statusCode})');
      final total = res.contentLength ?? 0;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  /// 안드로이드 설치 화면을 띄워요. 마지막 "설치"는 회원이 직접 눌러요.
  static Future<void> install(File apk) => _channel.invokeMethod('install', {'path': apk.path});
}
