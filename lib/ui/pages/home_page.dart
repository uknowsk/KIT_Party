import 'package:flutter/material.dart';

import '../../models/ledger_math.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'ledger_page.dart';
import 'txn_editor.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onOpenDues});

  final VoidCallback? onOpenDues;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final settings = s.settings!;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final balance = LedgerMath.balance(settings, s.txns);
    final monthIn = LedgerMath.sum(s.txns, type: TxnType.income, year: now.year, month: now.month);
    final monthOut = LedgerMath.sum(s.txns, type: TxnType.expense, year: now.year, month: now.month);
    final interest = LedgerMath.sum(s.txns, category: Categories.interest, year: now.year);
    final me = s.me;
    final myDues = me == null
        ? null
        : LedgerMath.dues(members: [me], txns: s.txns, settings: settings, asOf: now).first;

    var i = 0;
    Widget item(Widget w) => FadeSlideIn(index: i++, child: w);

    return LargeTitlePage(
      title: '회비장부',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(children: [
            item(AppCard(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('지금 잔고', style: tt.labelMedium),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: CountUp(balance, style: tt.displaySmall!.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
                ),
                const SizedBox(height: 6),
                Text('시작 잔고 ${won(settings.openingBalance)} · ${yearMonth(settings.openingDate)}부터',
                    style: tt.bodySmall),
              ]),
            )),
            const SizedBox(height: 12),
            item(Row(children: [
              Expanded(child: _Stat(label: '${now.month}월 수입', value: monthIn, color: AppColors.green)),
              const SizedBox(width: 12),
              Expanded(child: _Stat(label: '${now.month}월 지출', value: monthOut)),
              const SizedBox(width: 12),
              Expanded(child: _Stat(label: '올해 이자', value: interest, color: AppColors.green)),
            ])),
            if (myDues != null) ...[
              const SizedBox(height: 12),
              item(_MyDuesCard(status: myDues, onTap: onOpenDues)),
            ],
            if (s.members.any((m) => m.birthMonth == now.month)) ...[
              const SizedBox(height: 12),
              item(_BirthdayCard(month: now.month, members: s.members)),
            ],
            if (s.isTreasurer) ...[
              const SizedBox(height: 12),
              item(Row(children: [
                Expanded(
                  child: _QuickButton(
                    icon: Icons.add_circle_rounded,
                    label: '기록 추가',
                    onTap: () => showTxnEditor(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickButton(
                    icon: Icons.savings_rounded,
                    label: '이자 입력',
                    onTap: () => showTxnEditor(context,
                        preset: Txn(
                          id: '',
                          date: DateTime(now.year, now.month, now.day),
                          type: TxnType.income,
                          category: Categories.interest,
                          item: '세이프박스 이자',
                          amount: 0,
                        )),
                  ),
                ),
              ])),
            ],
          ]),
        ),
        const SliverToBoxAdapter(child: SectionHeader('한눈에 보기')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(child: _Charts(year: now.year, lastMonth: now.month, startIndex: i)),
        ),
        const SliverToBoxAdapter(child: SectionHeader('최근 기록')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                for (final (j, t) in s.txns.take(5).indexed)
                  FadeSlideIn(
                    index: i + j,
                    child: TxnTile(
                      txn: t,
                      memberName: s.memberById(t.memberId)?.name,
                      onTap: () => showTxnDetail(context, t),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _Charts extends StatelessWidget {
  const _Charts({required this.year, required this.lastMonth, required this.startIndex});

  final int year;
  final int lastMonth;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final settings = s.settings!;
    final trend = BalanceTrendCard(
      balances: LedgerMath.monthEndBalances(settings, s.txns, year, lastMonth),
      opening: settings.openingBalance,
    );
    final flows = MonthlyFlowCard(flows: LedgerMath.monthlyFlows(s.txns, year, lastMonth));
    final donut = ExpenseDonutCard(year: year, parts: LedgerMath.expenseByCategory(s.txns, year));
    var k = startIndex;
    Widget item(Widget w) => FadeSlideIn(index: k++, child: w);
    // 가로로 넓은 화면에선 두 개씩 나란히.
    if (MediaQuery.sizeOf(context).width >= 760) {
      return Column(children: [
        item(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: trend),
            const SizedBox(width: 12),
            Expanded(child: flows),
          ]),
        )),
        const SizedBox(height: 12),
        item(donut),
      ]);
    }
    return Column(children: [
      item(trend),
      const SizedBox(height: 12),
      item(flows),
      const SizedBox(height: 12),
      item(donut),
    ]);
  }
}

/// 이번 달 생일인 회원들. 생일 순서로.
class _BirthdayCard extends StatelessWidget {
  const _BirthdayCard({required this.month, required this.members});

  final int month;
  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final list = members.where((m) => m.birthMonth == month).toList()
      ..sort((a, b) => a.birthDay!.compareTo(b.birthDay!));
    return AppCard(
      child: Row(children: [
        const Text('🎂', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$month월 생일', style: tt.labelMedium),
            const SizedBox(height: 2),
            Text(
              list.map((m) => '${m.name} ${m.birthDay}일').join(' · '),
              style: tt.titleSmall,
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: tt.labelMedium, maxLines: 1),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: CountUp(value, style: tt.titleMedium!.copyWith(color: color)),
        ),
      ]),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: c, size: 20),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: c)),
      ]),
    );
  }
}

class _MyDuesCard extends StatelessWidget {
  const _MyDuesCard({required this.status, this.onTap});

  final DuesStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (text, color) = status.exempt
        ? ('${status.year}년 회비 면제', AppColors.gray)
        : status.isUnpaid
            ? ('${won(status.unpaid)} 남았어요', AppColors.red)
            : ('${status.monthsCovered}월분까지 냈어요', AppColors.green);
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('내 회비', style: tt.labelMedium),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, color: AppColors.gray, size: 20),
        ]),
        const SizedBox(height: 4),
        Text(text, style: tt.titleMedium!.copyWith(color: color)),
        const SizedBox(height: 10),
        DuesBar(progress: status.yearProgress, color: color),
      ]),
    );
  }
}

/// 한 해 회비 중 낸 만큼 차오르는 막대.
class DuesBar extends StatelessWidget {
  const DuesBar({super.key, required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 6,
          child: Stack(children: [
            Container(color: Theme.of(context).scaffoldBackgroundColor),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(widthFactor: v, child: Container(color: color)),
            ),
          ]),
        ),
      );
}
