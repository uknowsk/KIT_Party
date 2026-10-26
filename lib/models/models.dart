/// 앱에 저장되는 데이터 모양.
library;

enum TxnType { income, expense }

/// 수입·지출 분류. 시트의 분류를 그대로 가져왔어요.
class Categories {
  static const dues = '회비';
  static const interest = '이자';
  static const otherIncome = '기타';
  static const income = [dues, interest, otherIncome];
  static const expense = ['정기모임', '번개', '경조사', '생일선물', '기타'];

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

  const Member({
    required this.id,
    required this.name,
    this.role = Role.member,
    this.uid,
    this.exemptYears = const [],
  });

  bool get isTreasurer => role == Role.treasurer;
  bool isExempt(int year) => exemptYears.contains(year);

  Member copyWith({Role? role, String? uid, List<int>? exemptYears}) => Member(
        id: id,
        name: name,
        role: role ?? this.role,
        uid: uid ?? this.uid,
        exemptYears: exemptYears ?? this.exemptYears,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role.name,
        'uid': uid,
        'exemptYears': exemptYears,
      };

  factory Member.fromMap(String id, Map<String, dynamic> m) => Member(
        id: id,
        name: m['name'] as String? ?? '',
        role: m['role'] == 'treasurer' ? Role.treasurer : Role.member,
        uid: m['uid'] as String?,
        exemptYears: [for (final y in (m['exemptYears'] as List? ?? [])) (y as num).toInt()],
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

  const LedgerSettings({
    required this.openingBalance,
    required this.openingDate,
    this.monthlyDues = 30000,
    this.latestVersion = '1.0.0',
    this.apkUrl,
  });

  Map<String, dynamic> toMap() => {
        'openingBalance': openingBalance,
        'openingDate': openingDate.toIso8601String().substring(0, 10),
        'monthlyDues': monthlyDues,
        'latestVersion': latestVersion,
        'apkUrl': apkUrl,
      };

  factory LedgerSettings.fromMap(Map<String, dynamic> m) => LedgerSettings(
        openingBalance: (m['openingBalance'] as num? ?? 0).toInt(),
        openingDate: DateTime.tryParse(m['openingDate'] as String? ?? '') ?? DateTime(2026),
        monthlyDues: (m['monthlyDues'] as num? ?? 30000).toInt(),
        latestVersion: m['latestVersion'] as String? ?? '1.0.0',
        apkUrl: m['apkUrl'] as String?,
      );
}
