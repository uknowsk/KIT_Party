/// 앱에 저장되는 데이터 모양.
library;

enum TxnType { income, expense }

/// 수입·지출 분류. 시트의 분류를 그대로 가져왔어요.
class Categories {
  static const dues = '회비';
  static const interest = '이자';
  static const otherIncome = '기타';
  static const income = [dues, interest, otherIncome];
  static const expense = [
    '정기모임', '번개', '식사', '숙박', '교통', '마트', '시설이용', '주차', '경조사', '생일선물', '기타', //
  ];

  static List<String> of(TxnType t) => t == TxnType.income ? income : expense;
}

enum Role { treasurer, member }

class Member {
  final String id;
  final String name;
  final Role role;

  /// 구글 로그인 후 총무가 승인하면 채워져요.
  final String? uid;

  /// 회비를 면제받는 해 (예: 2026).
  final List<int> exemptYears;

  /// 생일 "MM-DD" (예: "03-14"). 총무가 넣어요. 연도는 안 받아요.
  final String? birthday;

  const Member({
    required this.id,
    required this.name,
    this.role = Role.member,
    this.uid,
    this.exemptYears = const [],
    this.birthday,
  });

  int? get birthMonth => birthday == null ? null : int.tryParse(birthday!.split('-').first);
  int? get birthDay => birthday == null ? null : int.tryParse(birthday!.split('-').last);

  /// "3월 14일" 처럼 보여줄 글자.
  String? get birthdayLabel => birthMonth == null ? null : '$birthMonth월 $birthDay일';

  static String birthdayKey(int month, int day) =>
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  bool get isTreasurer => role == Role.treasurer;
  bool isExempt(int year) => exemptYears.contains(year);

  Member copyWith({Role? role, String? uid, List<int>? exemptYears}) => Member(
        id: id,
        name: name,
        role: role ?? this.role,
        uid: uid ?? this.uid,
        exemptYears: exemptYears ?? this.exemptYears,
        birthday: birthday,
      );

  Member withBirthday(String? value) => Member(
        id: id,
        name: name,
        role: role,
        uid: uid,
        exemptYears: exemptYears,
        birthday: value,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role.name,
        'uid': uid,
        'exemptYears': exemptYears,
        'birthday': birthday,
      };

  factory Member.fromMap(String id, Map<String, dynamic> m) => Member(
        id: id,
        name: m['name'] as String? ?? '',
        role: m['role'] == 'treasurer' ? Role.treasurer : Role.member,
        uid: m['uid'] as String?,
        exemptYears: [for (final y in (m['exemptYears'] as List? ?? [])) (y as num).toInt()],
        birthday: m['birthday'] as String?,
      );
}

/// 입출금 기록 1건.
class Txn {
  final String id;
  final DateTime date;
  final TxnType type;
  final String category;
  final String item;
  final int amount;

  /// 회비·생일선물처럼 특정 회원과 관련된 기록이면 그 회원 id.
  final String? memberId;
  final String? memo;
  final String? receiptUrl;

  const Txn({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.item,
    required this.amount,
    this.memberId,
    this.memo,
    this.receiptUrl,
  });

  bool get isIncome => type == TxnType.income;
  int get signed => isIncome ? amount : -amount;

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String().substring(0, 10),
        'type': type.name,
        'category': category,
        'item': item,
        'amount': amount,
        'memberId': memberId,
        'memo': memo,
        'receiptUrl': receiptUrl,
      };

  factory Txn.fromMap(String id, Map<String, dynamic> m) => Txn(
        id: id,
        date: DateTime.parse(m['date'] as String),
        type: m['type'] == 'expense' ? TxnType.expense : TxnType.income,
        category: m['category'] as String? ?? '',
        item: m['item'] as String? ?? '',
        amount: (m['amount'] as num? ?? 0).toInt(),
        memberId: m['memberId'] as String?,
        memo: m['memo'] as String?,
        receiptUrl: m['receiptUrl'] as String?,
      );
}

class Message {
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final bool pinned;

  const Message({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.pinned = false,
  });

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'pinned': pinned,
      };

  factory Message.fromMap(String id, Map<String, dynamic> m) => Message(
        id: id,
        authorId: m['authorId'] as String? ?? '',
        authorName: m['authorName'] as String? ?? '',
        text: m['text'] as String? ?? '',
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        pinned: m['pinned'] as bool? ?? false,
      );
}

/// 장부 전체 설정 (시트의 '설정' 탭).
class LedgerSettings {
  final int openingBalance;
  final DateTime openingDate;
  final int monthlyDues;
  final String latestVersion;
  final String? apkUrl;

  /// 회장 회원 id. 명단에 '회장' 배지로 보여요.
  final String? presidentId;

  /// 정기모임 지역 도는 순서. 비어 있으면 기본 순서.
  final List<String> rotation;

  const LedgerSettings({
    required this.openingBalance,
    required this.openingDate,
    this.monthlyDues = 30000,
    this.latestVersion = '1.0.0',
    this.apkUrl,
    this.presidentId,
    this.rotation = Regions.all,
  });

  LedgerSettings copyWith({String? presidentId, List<String>? rotation}) => LedgerSettings(
        openingBalance: openingBalance,
        openingDate: openingDate,
        monthlyDues: monthlyDues,
        latestVersion: latestVersion,
        apkUrl: apkUrl,
        presidentId: presidentId ?? this.presidentId,
        rotation: rotation ?? this.rotation,
      );

  Map<String, dynamic> toMap() => {
        'openingBalance': openingBalance,
        'openingDate': openingDate.toIso8601String().substring(0, 10),
        'monthlyDues': monthlyDues,
        'latestVersion': latestVersion,
        'apkUrl': apkUrl,
        'presidentId': presidentId,
        'rotation': rotation,
      };

  factory LedgerSettings.fromMap(Map<String, dynamic> m) => LedgerSettings(
        openingBalance: (m['openingBalance'] as num? ?? 0).toInt(),
        openingDate: DateTime.tryParse(m['openingDate'] as String? ?? '') ?? DateTime(2026),
        monthlyDues: (m['monthlyDues'] as num? ?? 30000).toInt(),
        latestVersion: m['latestVersion'] as String? ?? '1.0.0',
        apkUrl: m['apkUrl'] as String?,
        presidentId: m['presidentId'] as String?,
        rotation: switch (m['rotation']) {
          final List l when l.isNotEmpty => [for (final r in l) '$r'],
          _ => Regions.all,
        },
      );
}

/// 정기모임 지역. 이 순서로 돌아가며 열어요.
class Regions {
  static const all = ['서울·경기', '충청', '경상', '부산'];
}

enum MeetingKind {
  regular('정기모임'),
  flash('번개');

  const MeetingKind(this.label);
  final String label;
}

/// 모임 한 번: 언제, 어디서, 누가 왔나.
class Meeting {
  final String id;
  final DateTime date;
  final MeetingKind kind;

  /// 정기모임 지역 (로테이션 계산에 써요). 번개는 비워도 돼요.
  final String? region;
  final String place;
  final List<String> attendeeIds;
  final String? memo;

  const Meeting({
    required this.id,
    required this.date,
    required this.kind,
    this.region,
    this.place = '',
    this.attendeeIds = const [],
    this.memo,
  });

  bool get isRegular => kind == MeetingKind.regular;

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String().substring(0, 10),
        'kind': kind.name,
        'region': region,
        'place': place,
        'attendeeIds': attendeeIds,
        'memo': memo,
      };

  factory Meeting.fromMap(String id, Map<String, dynamic> m) => Meeting(
        id: id,
        date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime(2026),
        kind: m['kind'] == 'flash' ? MeetingKind.flash : MeetingKind.regular,
        region: m['region'] as String?,
        place: m['place'] as String? ?? '',
        attendeeIds: [for (final a in (m['attendeeIds'] as List? ?? [])) '$a'],
        memo: m['memo'] as String?,
      );

  Meeting withId(String id) =>
      Meeting(id: id, date: date, kind: kind, region: region, place: place, attendeeIds: attendeeIds, memo: memo);
}

/// 투표: 고를 것들과 한 개만/여러 개 고르기.
class Poll {
  final List<String> options;
  final bool multi;
  final DateTime? deadline;

  const Poll({required this.options, this.multi = false, this.deadline});

  Map<String, dynamic> toMap() => {
        'options': options,
        'multi': multi,
        'deadline': deadline?.toIso8601String(),
      };

  factory Poll.fromMap(Map<String, dynamic> m) => Poll(
        options: [for (final o in (m['options'] as List? ?? [])) '$o'],
        multi: m['multi'] as bool? ?? false,
        deadline: DateTime.tryParse(m['deadline'] as String? ?? ''),
      );
}

/// 공지 한 건. 투표가 붙을 수 있어요.
class Notice {
  final String id;
  final String authorId;
  final String authorName;
  final String title;
  final String body;
  final DateTime createdAt;
  final Poll? poll;

  /// 회원 id → 고른 번호들.
  final Map<String, List<int>> votes;

  /// 총무가 투표를 마감했는지.
  final bool closed;

  const Notice({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    this.body = '',
    required this.createdAt,
    this.poll,
    this.votes = const {},
    this.closed = false,
  });

  /// 투표를 더 받을 수 있는지 (마감 버튼이나 마감 시각).
  bool isOpen(DateTime now) =>
      poll != null && !closed && (poll!.deadline == null || now.isBefore(poll!.deadline!));

  List<int> choicesOf(String memberId) => votes[memberId] ?? const [];

  /// 번호마다 몇 명이 골랐나.
  List<int> get counts {
    final c = List.filled(poll?.options.length ?? 0, 0);
    for (final v in votes.values) {
      for (final i in v) {
        if (i >= 0 && i < c.length) c[i]++;
      }
    }
    return c;
  }

  /// 한 번이라도 고른 사람 수.
  int get voters => votes.values.where((v) => v.isNotEmpty).length;

  /// 번호마다 고른 회원 id.
  List<String> votersOf(int option) => [
        for (final e in votes.entries)
          if (e.value.contains(option)) e.key,
      ];

  Notice copyWith({Map<String, List<int>>? votes, bool? closed, String? id}) => Notice(
        id: id ?? this.id,
        authorId: authorId,
        authorName: authorName,
        title: title,
        body: body,
        createdAt: createdAt,
        poll: poll,
        votes: votes ?? this.votes,
        closed: closed ?? this.closed,
      );

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'poll': poll?.toMap(),
        'votes': votes,
        'closed': closed,
      };

  factory Notice.fromMap(String id, Map<String, dynamic> m) => Notice(
        id: id,
        authorId: m['authorId'] as String? ?? '',
        authorName: m['authorName'] as String? ?? '',
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        poll: m['poll'] is Map ? Poll.fromMap(Map<String, dynamic>.from(m['poll'] as Map)) : null,
        votes: {
          for (final e in (m['votes'] as Map? ?? {}).entries)
            '${e.key}': [for (final i in (e.value as List? ?? [])) (i as num).toInt()],
        },
        closed: m['closed'] as bool? ?? false,
      );
}
