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
            tile('역할',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (s.isPresident) ...[const Badge2('회장', color: AppColors.orange), const SizedBox(width: 6)],
                  if (s.isTreasurer) const Badge2('총무', color: AppColors.blue),
                  if (!s.isPresident && !s.isTreasurer) const Badge2('회원', color: AppColors.gray),
                ])),
            if (onSignOut != null) tile('로그아웃', color: AppColors.red, onTap: onSignOut),
          ]),
          SectionHeader('회원 명단 · ${s.members.length}명'),
          group([
            for (final m in s.members)
              tile(m.name,
                  onTap: s.isTreasurer ? () => _memberMenu(context, m) : null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (m.birthdayLabel != null) ...[
                      Text('🎂 ${m.birthdayLabel}', style: tt.bodySmall!.copyWith(color: AppColors.gray)),
                      const SizedBox(width: 6),
                    ],
                    if (m.isExempt(DateTime.now().year)) const Badge2('면제', color: AppColors.gray),
                    if (s.isPresidentMember(m)) ...[
                      const SizedBox(width: 6),
                      const Badge2('회장', color: AppColors.orange),
                    ],
                    if (m.isTreasurer) ...[
                      const SizedBox(width: 6),
                      const Badge2('총무', color: AppColors.blue),
                    ],
                    if (s.isTreasurer) const Icon(Icons.chevron_right_rounded, color: AppColors.gray),
                  ])),
          ]),
          if (s.isTreasurer)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
              child: Text('이름을 누르면 생일을 넣거나 ${DateTime.now().year}년 회비 면제를 정할 수 있어요.',
                  style: tt.bodySmall!.copyWith(color: AppColors.gray)),
            ),
          if (s.isTreasurer) ...[
            const SectionHeader('총무 메뉴'),
            group([
              tile('회장 정하기',
                  value: s.memberById(s.presidentId)?.name,
                  onTap: () => _pickMember(context, '누가 회장인가요?', (m) => _run(context, () => repo.setPresident(m.id)))),
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

  /// 총무: 회원 한 명의 생일과 올해 회비 면제를 정하는 메뉴.
  void _memberMenu(BuildContext context, Member m) {
    final s = AppScope.of(context);
    final year = DateTime.now().year;
    final exempt = m.isExempt(year);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: Text(m.name),
        message: Text('생일 ${m.birthdayLabel ?? '미입력'} · $year년 회비 ${exempt ? '면제 중' : '내는 중'}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(c);
              _pickBirthday(context, m);
            },
            child: Text(m.birthday == null ? '생일 넣기' : '생일 바꾸기'),
          ),
          if (m.birthday != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(c);
                _run(context, () => s.repo.setBirthday(m.id, null));
              },
              child: const Text('생일 지우기'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: exempt,
            onPressed: () {
              Navigator.pop(c);
              _run(context, () => s.repo.setExempt(m.id, year, !exempt));
            },
            child: Text(exempt ? '회비 면제 풀기' : '회비 면제하기'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(c), child: const Text('취소')),
      ),
    );
  }

  /// 월·일 두 바퀴로 생일 고르기.
  void _pickBirthday(BuildContext context, Member m) {
    final s = AppScope.of(context);
    var month = m.birthMonth ?? 1;
    var day = m.birthDay ?? 1;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (c) {
        final bg = CupertinoColors.systemBackground.resolveFrom(c);
        return Container(
          color: bg,
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                CupertinoButton(onPressed: () => Navigator.pop(c), child: const Text('취소')),
                Expanded(
                  child: Text('${m.name} 생일',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                ),
                CupertinoButton(
                  onPressed: () {
                    Navigator.pop(c);
                    // 2월 30일 같은 날은 그 달 마지막 날로 (2월은 29일까지 허용).
                    final last = DateTime(2024, month + 1, 0).day;
                    final d = day > last ? last : day;
                    _run(context, () => s.repo.setBirthday(m.id, Member.birthdayKey(month, d)));
                  },
                  child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
              SizedBox(
                height: 200,
                child: Row(children: [
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 36,
                      scrollController: FixedExtentScrollController(initialItem: month - 1),
                      onSelectedItemChanged: (i) => month = i + 1,
                      children: [for (var i = 1; i <= 12; i++) Center(child: Text('$i월'))],
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      itemExtent: 36,
                      scrollController: FixedExtentScrollController(initialItem: day - 1),
                      onSelectedItemChanged: (i) => day = i + 1,
                      children: [for (var i = 1; i <= 31; i++) Center(child: Text('$i일'))],
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  /// 저장하다 실패하면(권한 없음 등) 아래에 짧게 알려줘요.
  Future<void> _run(BuildContext context, Future<void> Function() job) async {
    try {
      await job();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장하지 못했어요: $e')));
      }
    }
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
