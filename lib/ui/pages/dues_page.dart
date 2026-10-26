import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/ledger_math.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_page.dart';

class DuesPage extends StatelessWidget {
  const DuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final settings = s.settings!;
    final list = LedgerMath.dues(members: s.members, txns: s.txns, settings: settings, asOf: now)
      ..sort((a, b) {
        int rank(DuesStatus d) => d.isUnpaid ? 0 : (d.exempt ? 2 : 1);
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : b.unpaid.compareTo(a.unpaid);
      });
    final unpaid = list.where((d) => d.isUnpaid).length;
    final exempt = list.where((d) => d.exempt).length;
    final done = list.length - unpaid - exempt;

    return LargeTitlePage(
      title: '회비',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: FadeSlideIn(
              index: 0,
              child: AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${now.year}년 회비 · 월 ${won(settings.monthlyDues)}', style: tt.labelMedium),
                  const SizedBox(height: 4),
                  Text('${now.month}월까지 1인당 ${won(settings.monthlyDues * now.month)}', style: tt.titleMedium),
                  const SizedBox(height: 14),
                  Row(children: [
                    _Count('미납', unpaid, AppColors.red),
                    _Count('완납', done, AppColors.green),
                    _Count('면제', exempt, AppColors.gray),
                  ]),
                  if (s.isTreasurer && unpaid > 0) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                      icon: const Icon(Icons.notifications_active_rounded),
                      label: Text('미납 $unpaid명에게 알림 보내기'),
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('푸시 알림은 다음 단계(핵심 기능)에서 연결돼요')),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionHeader('회원별')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(builder: (context, c) {
            final cols = c.crossAxisExtent >= 760 ? 3 : (c.crossAxisExtent >= 520 ? 2 : 1);
            return SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                // 글씨 크기 설정에 맞춰 카드 높이도 늘어나요.
                mainAxisExtent: 32 + MediaQuery.textScalerOf(context).scale(74),
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => FadeSlideIn(index: i + 1, child: _MemberDues(status: list[i])),
            );
          }),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.n, this.color);

  final String label;
  final int n;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: n.toDouble()),
            duration: const Duration(milliseconds: 700),
            builder: (_, v, _) => Text('${v.round()}',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(color: color)),
          ),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ]),
      );
}

class _MemberDues extends StatelessWidget {
  const _MemberDues({required this.status});

  final DuesStatus status;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (text, color) = status.exempt
        ? ('면제', AppColors.gray)
        : status.isUnpaid
            ? ('미납 ${won(status.unpaid)}', AppColors.red)
            : ('${status.monthsCovered}월분까지', AppColors.green);
    return AppCard(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _MemberDuesSheet(memberId: status.member.id),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [
          Text(status.member.name, style: tt.titleMedium),
          if (status.member.isTreasurer) ...[
            const SizedBox(width: 6),
            const Badge2('총무', color: AppColors.blue),
          ],
          const Spacer(),
          Text(text, style: tt.labelLarge!.copyWith(color: color)),
        ]),
        const SizedBox(height: 6),
        Text('낸 금액 ${won(status.paid)}', style: tt.bodySmall),
        const SizedBox(height: 8),
        DuesBar(progress: status.yearProgress, color: color),
      ]),
    );
  }
}

/// 회원 한 명의 월별 납부 내역 + (총무) 면제 설정.
class _MemberDuesSheet extends StatelessWidget {
  const _MemberDuesSheet({required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final m = s.memberById(memberId)!;
    final now = DateTime.now();
    final st = LedgerMath.dues(members: [m], txns: s.txns, settings: s.settings!, asOf: now).first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${m.name} · ${st.year}년 회비', style: tt.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        AppCard(
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            children: [
              for (var i = 0; i < 12; i++)
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${i + 1}월', style: tt.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    st.paidByMonth[i] == 0 ? '–' : won(st.paidByMonth[i]).replaceAll('원', ''),
                    style: tt.bodyMedium!.copyWith(
                      fontWeight: st.paidByMonth[i] == 0 ? null : FontWeight.w600,
                      color: st.paidByMonth[i] == 0 ? AppColors.gray : AppColors.green,
                    ),
                  ),
                ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(children: [
            Text('합계', style: tt.bodyMedium),
            const Spacer(),
            Text('${won(st.paid)} / ${won(st.monthly * 12)}', style: tt.titleMedium),
          ]),
        ),
        if (s.isTreasurer) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(child: Text('${st.year}년 회비 면제', style: tt.bodyLarge)),
              CupertinoSwitch(
                value: m.isExempt(st.year),
                onChanged: (v) => s.repo.setExempt(m.id, st.year, v),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
