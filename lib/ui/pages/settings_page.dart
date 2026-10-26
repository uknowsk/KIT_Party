import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../data/firestore_repository.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ledger_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final me = s.me;
    final repo = s.repo;

    Widget group(List<Widget> rows) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              for (final (i, r) in rows.indexed) ...[
                if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 16, color: Theme.of(context).dividerColor),
                r,
              ],
            ]),
          ),
        );

    Widget tile(String title, {String? value, Widget? trailing, VoidCallback? onTap, Color? color}) {
      final row = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Expanded(child: Text(title, style: tt.bodyLarge!.copyWith(color: color))),
          if (value != null) Text(value, style: tt.bodyLarge!.copyWith(color: AppColors.gray)),
          ?trailing,
          if (onTap != null && trailing == null)
            const Icon(Icons.chevron_right_rounded, color: AppColors.gray),
        ]),
      );
      return onTap == null ? row : Pressable(onTap: onTap, child: row);
    }

    return LargeTitlePage(
      title: '설정',
      slivers: [
        SliverList.list(children: [
          if (repo.isDemo) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppCard(
                child: Row(children: [
                  const Icon(Icons.science_rounded, color: AppColors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('체험 모드예요. 시트 데이터로 미리 보는 중이고, 바꾼 내용은 저장되지 않아요.',
                        style: tt.bodyMedium),
                  ),
                ]),
              ),
            ),
            const SectionHeader('누구로 볼까요?'),
            group([
              tile('보는 사람', value: me?.name, onTap: () => _pickMember(context, '누구로 볼까요?', (m) => s.actAs(m.id))),
            ]),
          ],
          const SectionHeader('내 정보'),
          group([
            tile('이름', value: me?.name ?? '-'),
            tile('역할', trailing: Badge2(s.isTreasurer ? '총무' : '회원', color: s.isTreasurer ? AppColors.blue : AppColors.gray)),
            if (onSignOut != null) tile('로그아웃', color: AppColors.red, onTap: onSignOut),
          ]),
          SectionHeader('회원 명단 · ${s.members.length}명'),
          group([
            for (final m in s.members)
              tile(m.name,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (m.isExempt(DateTime.now().year)) const Badge2('면제', color: AppColors.gray),
                    if (m.isTreasurer) ...[
                      const SizedBox(width: 6),
                      const Badge2('총무', color: AppColors.blue),
                    ],
                  ])),
          ]),
          if (s.isTreasurer) ...[
            const SectionHeader('총무 메뉴'),
            group([
              tile('총무 넘기기', onTap: () => _pickMember(context, '누구에게 넘길까요?', (to) async {
                    if (to.id == me!.id) return;
                    final ok = await confirm(context, '${to.name}님에게 총무를 넘길까요?', '넘기면 바로 회원 권한으로 바뀌어요.');
                    if (!ok) return;
                    try {
                      await repo.transferTreasurer(me.id, to.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  })),
            ]),
            if (repo is FirestoreRepository) _JoinRequests(repo: repo),
          ],
          const SectionHeader('앱 정보'),
          group([
            tile('버전', value: appVersion),
            tile('데이터', value: repo.isDemo ? '체험 모드' : '실시간 동기화'),
          ]),
        ]),
      ],
    );
  }

  void _pickMember(BuildContext context, String title, void Function(Member) onPick) {
    final s = AppScope.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final m in s.members)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(c);
                onPick(m);
              },
              child: Text(m.isTreasurer ? '${m.name} (총무)' : m.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(c), child: const Text('취소')),
      ),
    );
  }
}

/// 총무: 가입 신청 승인.
class _JoinRequests extends StatelessWidget {
  const _JoinRequests({required this.repo});

  final FirestoreRepository repo;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return StreamBuilder(
      stream: repo.joinRequests(),
      builder: (context, snap) {
        final reqs = snap.data ?? const [];
        if (reqs.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeader('가입 신청 · ${reqs.length}건'),
          for (final r in reqs)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AppCard(
                child: Row(children: [
                  Expanded(
                    child: Text('${s.memberById(r.memberId)?.name ?? '?'} · ${r.email ?? ''}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  TextButton(onPressed: () => repo.approveJoin(r.uid, r.memberId), child: const Text('승인')),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
