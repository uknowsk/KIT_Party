import 'models.dart';

/// 장소 로테이션과 참석률 계산. 저장하지 않고 모임 기록에서 매번 계산해요.
class MeetingMath {
  /// 날짜가 가장 늦은 정기모임 (지역이 적힌 것만).
  static Meeting? lastRegular(Iterable<Meeting> meetings) {
    Meeting? last;
    for (final m in meetings) {
      if (m.isRegular && m.region != null && (last == null || !m.date.isBefore(last.date))) last = m;
    }
    return last;
  }

  /// 다음 정기모임 지역: 마지막 정기모임 지역의 다음 차례. 기록이 없으면 첫 번째.
  static String nextRegion(List<String> rotation, Iterable<Meeting> meetings) {
    final order = rotation.isEmpty ? Regions.all : rotation;
    final i = order.indexOf(lastRegular(meetings)?.region ?? '');
    return order[(i + 1) % order.length];
  }

  /// 지역마다 마지막으로 정기모임을 연 날.
  static Map<String, DateTime> lastVisits(Iterable<Meeting> meetings) {
    final map = <String, DateTime>{};
    for (final m in meetings) {
      if (!m.isRegular || m.region == null) continue;
      final d = map[m.region!];
      if (d == null || m.date.isAfter(d)) map[m.region!] = m.date;
    }
    return map;
  }

  /// 회원별 참석 횟수와 비율, 많이 온 순서.
  static List<Attendance> attendance(
    List<Member> members,
    Iterable<Meeting> meetings, {
    MeetingKind? kind,
    int? year,
  }) {
    final picked = meetings.where((m) => (kind == null || m.kind == kind) && (year == null || m.date.year == year));
    final total = picked.length;
    final list = [
      for (final mem in members)
        Attendance(
          member: mem,
          attended: picked.where((m) => m.attendeeIds.contains(mem.id)).length,
          total: total,
        ),
    ];
    list.sort((a, b) => b.attended != a.attended ? b.attended.compareTo(a.attended) : a.member.name.compareTo(b.member.name));
    return list;
  }
}

class Attendance {
  final Member member;
  final int attended;
  final int total;

  const Attendance({required this.member, required this.attended, required this.total});

  /// 0~1
  double get rate => total == 0 ? 0 : attended / total;
  int get percent => (rate * 100).round();
}
