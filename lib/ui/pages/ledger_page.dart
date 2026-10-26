import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/ledger_math.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'txn_editor.dart';

enum _Filter { all, income, expense }

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  var _filter = _Filter.all;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final txns = s.txns.where((t) => switch (_filter) {
          _Filter.all => true,
          _Filter.income => t.isIncome,
          _Filter.expense => !t.isIncome,
        });

    // 월별로 묶기 (최신 달이 위로)
    final byMonth = <DateTime, List<Txn>>{};
    for (final t in txns) {
      byMonth.putIfAbsent(DateTime(t.date.year, t.date.month), () => []).add(t);
    }

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 760;
      Txn? selected;
      for (final t in s.txns) {
        if (t.id == _selectedId) selected = t;
      }

      final list = LargeTitlePage(
        title: '장부',
        floating: s.isTreasurer
            ? FloatingActionButton(
                onPressed: () => showTxnEditor(context),
                shape: const CircleBorder(),
                child: const Icon(Icons.add_rounded, size: 30),
              )
            : null,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: CupertinoSlidingSegmentedControl<_Filter>(
                groupValue: _filter,
                onValueChanged: (v) => setState(() => _filter = v!),
                children: const {
                  _Filter.all: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('전체')),
                  _Filter.income: Text('수입'),
                  _Filter.expense: Text('지출'),
                },
              ),
            ),
          ),
          for (final e in byMonth.entries) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                yearMonth(e.key),
                trailing: Text(
                  '+${won(LedgerMath.sum(e.value, type: TxnType.income)).replaceAll('원', '')}   '
                  '−${won(LedgerMath.sum(e.value, type: TxnType.expense)).replaceAll('원', '')}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    for (final (i, t) in e.value.indexed)
                      FadeSlideIn(
                        key: ValueKey('${_filter.name}${t.id}'),
                        index: i,
                        child: TxnTile(
                          txn: t,
                          memberName: s.memberById(t.memberId)?.name,
                          selected: wide && t.id == _selectedId,
                          onTap: () => wide ? setState(() => _selectedId = t.id) : showTxnDetail(context, t),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ],
        ],
      );

      if (!wide) return list;
      // 가로 화면: 왼쪽 목록 + 오른쪽 상세
      return Row(children: [
        SizedBox(width: c.maxWidth * 0.55, child: list),
        VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: selected == null
                ? Center(
                    child: Text('기록을 눌러 자세히 보기', style: Theme.of(context).textTheme.bodySmall),
                  )
                : SingleChildScrollView(
                    key: ValueKey(selected.id),
                    padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
                    child: TxnDetail(txn: selected),
                  ),
          ),
        ),
      ]);
    });
  }
}

Future<void> showTxnDetail(BuildContext context, Txn t) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: AppScope.carry(
        context,
        (_) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: TxnDetail(txn: t, inSheet: true),
        ),
      ),
    );

class TxnDetail extends StatelessWidget {
  const TxnDetail({super.key, required this.txn, this.inSheet = false});

  final Txn txn;
  final bool inSheet;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final member = s.memberById(txn.memberId);
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Text(k, style: tt.bodyMedium!.copyWith(color: AppColors.gray)),
            const Spacer(),
            Flexible(child: Text(v, style: tt.bodyMedium, textAlign: TextAlign.right)),
          ]),
        );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: categoryColor(txn.category).withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(categoryIcon(txn.category), color: categoryColor(txn.category), size: 28),
        ),
      ),
      const SizedBox(height: 12),
      Text(txn.item, style: tt.titleMedium, textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(
        '${wonSigned(txn.signed)}원',
        style: tt.headlineMedium!.copyWith(color: txn.isIncome ? AppColors.green : null),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [
          row('날짜', '${txn.date.year}년 ${monthDay(txn.date)}'),
          row('분류', '${txn.isIncome ? '수입' : '지출'} · ${txn.category}'),
          if (member != null) row('관련 회원', member.name),
          if (txn.memo?.isNotEmpty ?? false) row('메모', txn.memo!),
        ]),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Row(children: [
          const Icon(Icons.receipt_long_rounded, color: AppColors.gray),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              txn.receiptUrl == null ? '영수증 없음' : '영수증 보기',
              style: tt.bodyMedium!.copyWith(color: AppColors.gray),
            ),
          ),
        ]),
      ),
      if (s.isTreasurer) ...[
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.red,
                side: BorderSide.none,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final ok = await confirm(context, '이 기록을 지울까요?', '지우면 되돌릴 수 없어요.');
                if (ok && context.mounted) {
                  await s.repo.deleteTxn(txn.id);
                  if (inSheet && context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('삭제'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () {
                if (inSheet) Navigator.pop(context);
                showTxnEditor(context, preset: txn);
              },
              child: const Text('수정'),
            ),
          ),
        ]),
      ],
    ]);
  }
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('확인'),
          ),
        ],
      ),
    ) ??
    false;
