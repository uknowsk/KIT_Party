/// 새 버전 정보 (GitHub Release 한 개).
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.notes, required this.apkUrl});

  /// 'v' 없이 숫자만. 예: 1.0.8
  final String version;

  /// 바뀐 내용, 한 줄에 하나씩.
  final List<String> notes;

  /// 설치 파일(APK) 주소.
  final String apkUrl;

  /// GitHub API의 /releases/latest 응답을 읽어요. APK가 없으면 null.
  static ReleaseInfo? fromGitHub(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    final assets = (json['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
    String? apk;
    for (final a in assets) {
      if ((a['name'] as String? ?? '').endsWith('.apk')) {
        apk = a['browser_download_url'] as String?;
        break;
      }
    }
    if (tag.isEmpty || apk == null) return null;
    return ReleaseInfo(version: cleanVersion(tag), notes: parseNotes(json['body'] as String? ?? ''), apkUrl: apk);
  }

  /// 'v1.0.8' / '1.0.8+9' → '1.0.8'
  static String cleanVersion(String v) => v.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;

  /// a가 b보다 새 버전이면 양수, 같으면 0, 옛날이면 음수.
  static int compare(String a, String b) {
    List<int> parts(String v) => [for (final p in cleanVersion(v).split('.')) int.tryParse(p) ?? 0];
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  /// GitHub이 만든 릴리즈 노트를 보기 좋게 다듬어요.
  /// "* 모임 탭 추가 by @someone in https://…/pull/10" → "모임 탭 추가"
  /// 제목줄(##)·"Full Changelog"·"New Contributors" 같은 건 뺍니다.
  static List<String> parseNotes(String body) {
    final out = <String>[];
    var skip = false;
    for (var line in body.split('\n')) {
      line = line.trim();
      if (line.startsWith('#')) {
        skip = line.toLowerCase().contains('new contributors');
        continue;
      }
      if (skip || line.isEmpty || line.startsWith('**Full Changelog')) continue;
      line = line
          .replaceFirst(RegExp(r'^[-*•]\s*'), '')
          .replaceFirst(RegExp(r'\s+by @\S+\s+in\s+\S+$'), '')
          .replaceAll('**', '');
      if (line.isNotEmpty) out.add(line);
    }
    return out;
  }
}
