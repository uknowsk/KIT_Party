import 'dart:math';

import 'models.dart';

/// 잔고·미납 계산. 저장하지 않고 매번 기록에서 계산해서 틀릴 일이 없어요.
class LedgerMath {
  static int balance(LedgerSettings s, Iterable<Txn> txns) =>
      s.openingBalance + txns.where((t) => !t.date.isBefore(s.openingDate)).fold(0, (a, t) => a + t.signed);

  static int sum(Iterable<Txn> txns, {TxnType? type, String? category, int? year, int? month}) => txns
      .where((t) =>
          (type == null || t.type == type) &&
          (category == null || t.category == category) &&
          (year == null || t.date.year == year) &&
          (month == null || t.date.month == month))
      .fold(0, (a, t) => a + t.amount);

  /// [asOf] 시점까지 한 해 동안 낼 회비와 낸 회비.
  static List<DuesStatus> dues({
    required List<Member> members,
    required Iterable<Txn> txns,
    required LedgerSettings settings,
    required DateTime asOf,
    int? year,
  }) {
    final y = year ?? asOf.year;
    final months = asOf.year > y ? 12 : (asOf.year < y ? 0 : asOf.month);
    return [
      for (final m in members)
        DuesStatus(
          member: m,
          year: y,
          monthly: settings.monthlyDues,
          due: m.isExempt(y) ? 0 : settings.monthlyDues * months,
          exempt: m.isExempt(y),
          paidByMonth: List.generate(
            12,
            (i) => sum(txns.where((t) => t.memberId == m.id),
                type: TxnType.income, category: Categories.dues, year: y, month: i + 1),
          ),
        ),
    ];
  }
}

class DuesStatus {
  final Member member;
  final int year;
  final int monthly;
  final int due;
  final bool exempt;
  final List<int> paidByMonth;

  const DuesStatus({
    required this.member,
    required this.year,
    required this.monthly,
    required this.due,
    required this.exempt,
    required this.paidByMonth,
  });

  int get paid => paidByMonth.fold(0, (a, b) => a + b);
  int get unpaid => max(0, due - paid);
  bool get isUnpaid => !exempt && unpaid > 0;

  /// 낸 돈으로 몇 개월치가 채워졌는지 (연 12개월 기준).
  int get monthsCovered => monthly == 0 ? 0 : min(12, paid ~/ monthly);

  /// 0~1, 1년치 대비 낸 비율 (진행 막대용).
  double get yearProgress => exempt ? 1 : (monthly == 0 ? 0 : min(1, paid / (monthly * 12)));
}
