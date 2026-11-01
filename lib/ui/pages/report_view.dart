import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/ledger_math.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'ledger_page.dart';

/// 한 달 동안 들어오고 나간 돈: 합계, 분류별, 기록 목록.
class MonthReport extends StatelessWidget {
  const MonthReport({super.key, required this.month, required this.onChange});

  final DateTime month;
  final ValueChanged<DateTime> onChange;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final y = month.year, m = month.month;
    final txns = s.txns.where((t) => t.date.year == y && t.date.month == m).toList();
    final first = _firstMonth(s);
    final now = DateTime.now();
    final last = DateTime(now.year, now.month);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PeriodStepper(
        key: const Key('monthStepper'),
        label: yearMonth(month),
        onPrev: month.isAfter(first) ? () => onChange(DateTime(y, m - 1)) : null,
        onNext: month.isBefore(last) ? () => onChange(DateTime(y, m + 1)) : null,
      ),
      _Totals(
        key: ValueKey('mt$y$m'),
        income: LedgerMath.sum(txns, type: TxnType.income),
        expense: LedgerMath.sum(txns, type: TxnType.expense),
      ),
      _Breakdown(title: '수입', parts: LedgerMath.byCategory(txns, TxnType.income, y, m)),
      _Breakdown(title: '지출', parts: LedgerMath.byCategory(txns, TxnType.expense, y, m)),
      const SectionHeader('이 달 기록'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: txns.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('이 달엔 기록이 없어요', style: Theme.of(context).textTheme.bodyMedium),
                )
              : Column(children: [
                  for (final (i, t) in txns.indexed)
                    FadeSlideIn(
                      key: ValueKey('r${t.id}'),
                      index: i,
                      child: TxnTile(
                        txn: t,
                        memberName: s.memberById(t.memberId)?.name,
                        onTap: () => showTxnDetail(context, t),
                      ),
                    ),
                ]),
        ),
      ),
    ]);
  }
}

/// 한 해 동안: 합계, 달마다 수입·지출, 분류별.
class YearReport extends StatelessWidget {
  const YearReport({super.key, required this.year, required this.onChange, required this.onOpenMonth});

  final int year;
  final ValueChanged<int> onChange;
  final ValueChanged<DateTime> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final lastMonth = year < now.year ? 12 : now.month;
    final txns = s.txns.where((t) => t.date.year == year).toList();
    final flows = LedgerMath.monthlyFlows(txns, year, lastMonth);
    final firstYear = _firstMonth(s).year;
    final firstMonthThisYear = year == firstYear ? _firstMonth(s).month : 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PeriodStepper(
        key: const Key('yearStepper'),
        label: '$year년',
        onPrev: year > firstYear ? () => onChange(year - 1) : null,
        onNext: year < now.year ? () => onChange(year + 1) : null,
      ),
      _Totals(
        key: ValueKey('yt$year'),
        income: LedgerMath.sum(txns, type: TxnType.income),
        expense: LedgerMath.sum(txns, type: TxnType.expense),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: MonthlyFlowCard(key: ValueKey('yf$year'), flows: flows),
      ),
      const SectionHeader('달마다'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (var m = lastMonth; m >= firstMonthThisYear; m--)
              Pressable(
                key: ValueKey('ym$m'),
                onTap: () => onOpenMonth(DateTime(year, m)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    SizedBox(width: 44, child: Text('$m월', style: tt.bodyLarge)),
                    Expanded(
                      child: Text(
                        '+${won(flows[m - 1].$1)}',
                        textAlign: TextAlign.right,
                        style: tt.bodyMedium!.copyWith(color: AppColors.green, fontFeatures: _tab),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '−${won(flows[m - 1].$2)}',
                        textAlign: TextAlign.right,
                        style: tt.bodyMedium!.copyWith(fontFeatures: _tab),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.gray, size: 20),
                  ]),
                ),
              ),
          ]),
        ),
      ),
      _Breakdown(title: '수입', parts: LedgerMath.byCategory(txns, TxnType.income, year)),
      _Breakdown(title: '지출', parts: LedgerMath.byCategory(txns, TxnType.expense, year)),
    ]);
  }
}

const _tab = [FontFeature.tabularFigures()];

/// 장부가 시작된 달 (기록 중 가장 이른 달과 시작일 중 더 이른 쪽).
DateTime _firstMonth(AppState s) {
  var d = s.settings!.openingDate;
  for (final t in s.txns) {
    if (t.date.isBefore(d)) d = t.date;
  }
  return DateTime(d.year, d.month);
}

class _Totals extends StatelessWidget {
  const _Totals({super.key, required this.income, required this.expense});

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final net = income - expense;
    Widget cell(String k, Widget v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: tt.labelMedium),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: v),
          ]),
        );
    final big = tt.titleMedium!.copyWith(fontWeight: FontWeight.w700, fontFeatures: _tab);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AppCard(
        child: Row(children: [
          cell('수입', CountUp(income, style: big.copyWith(color: AppColors.green))),
          const SizedBox(width: 10),
          cell('지출', CountUp(expense, style: big)),
          const SizedBox(width: 10),
          cell(
            net >= 0 ? '남은 돈' : '모자란 돈',
            CountUp(net.abs(), style: big.copyWith(color: net >= 0 ? AppColors.blue : AppColors.red)),
          ),
        ]),
      ),
    );
  }
}

/// 분류별 금액 막대.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.parts});

  final String title;
  final List<(String, int)> parts;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final total = parts.fold<int>(0, (a, p) => a + p.$2);
    final top = parts.isEmpty ? 1 : parts.first.$2;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader('$title 항목별', trailing: Text(won(total), style: tt.labelMedium)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppCard(
          child: parts.isEmpty
              ? Text('$title 없음', style: tt.bodyMedium)
              : Column(children: [
                  for (final (i, (name, v)) in parts.indexed)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(categoryIcon(name), size: 18, color: categoryColor(name)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(name, style: tt.bodyMedium)),
                          Text(
                            '${won(v)}  ${(v * 100 / math.max(total, 1)).round()}%',
                            style: tt.bodySmall!.copyWith(fontFeatures: _tab, color: tt.bodyMedium!.color),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        Container(
                          height: 6,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.centerLeft,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: v / top),
                            duration: Duration(milliseconds: 600 + 60 * i.clamp(0, 8)),
                            curve: Curves.easeOutCubic,
                            builder: (_, f, _) => FractionallySizedBox(
                              widthFactor: f,
                              heightFactor: 1,
                              child: ColoredBox(color: categoryColor(name)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                ]),
        ),
      ),
    ]);
  }
}
