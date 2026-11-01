import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/sheet.dart';
import 'ledger_page.dart';
import 'meetings_page.dart';
import 'messages_page.dart';

/// 소식 탭: 공지·투표 / 대화(메시지).
class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('소식'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _tab,
                  onValueChanged: (v) => setState(() => _tab = v!),
                  children: const {
                    0: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('공지·투표')),
                    1: Text('대화'),
                  },
                ),
              ),
            ),
          ),
        ),
        body: _tab == 0 ? const NoticesView() : const MessagesPage(embedded: true),
      );
}

class NoticesView extends StatelessWidget {
  const NoticesView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      floatingActionButton: s.canManageEvents
          ? FloatingActionButton(
              tooltip: '새 공지',
              onPressed: () => showAppSheet(context, (_) => const NoticeEditor(), scrollable: false),
              shape: const CircleBorder(),
              child: const Icon(Icons.edit_rounded),
            )
          : null,
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (s.rulesOutdated && s.canManageEvents) const RulesBanner(),
          if (s.notices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                s.canManageEvents ? '아직 공지가 없어요.\n✏️ 버튼으로 공지나 투표를 올려 보세요.' : '아직 공지가 없어요.',
                style: tt.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          for (final (i, n) in s.notices.indexed)
            FadeSlideIn(
              key: ValueKey(n.id),
              index: i,
              child: Padding(padding: const EdgeInsets.only(bottom: 12), child: NoticeCard(notice: n)),
            ),
        ],
      ),
    );
  }
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.notice});

  final Notice notice;

  Future<void> _tap(BuildContext context, int option) async {
    final s = AppScope.of(context);
    final me = s.me;
    if (me == null || !notice.isOpen(DateTime.now())) return;
    final mine = notice.choicesOf(me.id);
    final next = notice.poll!.multi
        ? (mine.contains(option) ? (mine.where((i) => i != option).toList()) : ([...mine, option]..sort()))
        : (mine.contains(option) ? <int>[] : [option]);
    HapticFeedback.selectionClick();
    try {
      await s.repo.vote(notice.id, me.id, next);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('투표가 안 됐어요: $e')));
      }
    }
  }

  void _menu(BuildContext context) {
    final s = AppScope.of(context);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        actions: [
          if (notice.poll != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(c);
                s.repo.setNoticeClosed(notice.id, !notice.closed);
              },
              child: Text(notice.closed ? '투표 다시 열기' : '투표 마감하기'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(c);
              if (await confirm(context, '공지를 지울까요?', '투표 결과도 함께 지워져요.')) {
                await s.repo.deleteNotice(notice.id);
              }
            },
            child: const Text('삭제'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(c), child: const Text('취소')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final n = notice;
    final poll = n.poll;
    final open = n.isOpen(DateTime.now());
    final counts = n.counts;
    final voters = n.voters;
    final mine = s.me == null ? const <int>[] : n.choicesOf(s.me!.id);
    final top = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (poll != null) ...[
            Badge2(open ? '투표 중' : '마감', color: open ? AppColors.blue : AppColors.gray),
            const SizedBox(width: 6),
          ] else ...[
            const Badge2('공지', color: AppColors.orange),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text('${n.authorName} · ${clock(n.createdAt)}', style: tt.bodySmall)),
          if (s.canManageEvents)
            GestureDetector(
              onTap: () => _menu(context),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.more_horiz_rounded, color: AppColors.gray),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text(n.title, style: tt.titleMedium),
        if (n.body.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(n.body, style: tt.bodyMedium),
        ],
        if (poll != null) ...[
          const SizedBox(height: 12),
          Text(
            [
              poll.multi ? '여러 개 고를 수 있어요' : '하나만 골라요',
              '$voters명 참여',
              if (poll.deadline != null) '${monthDay(poll.deadline!)}까지',
            ].join(' · '),
            style: tt.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final (i, label) in poll.options.indexed)
            _OptionRow(
              key: ValueKey('${n.id}_opt$i'),
              label: label,
              count: counts[i],
              share: voters == 0 ? 0 : counts[i] / voters,
              leading: top > 0 && counts[i] == top,
              picked: mine.contains(i),
              multi: poll.multi,
              names: [for (final id in n.votersOf(i)) s.memberById(id)?.name ?? '?'],
              onTap: open && s.me != null ? () => _tap(context, i) : null,
            ),
          if (open && s.me != null && mine.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('눌러서 투표해요', style: tt.bodySmall!.copyWith(color: AppColors.blue)),
            ),
        ],
      ]),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.label,
    required this.count,
    required this.share,
    required this.leading,
    required this.picked,
    required this.multi,
    required this.names,
    this.onTap,
  });

  final String label;
  final int count;
  final double share;
  final bool leading;
  final bool picked;
  final bool multi;
  final List<String> names;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final icon = multi
        ? (picked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
        : (picked ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded);
    final row = Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: picked ? AppColors.blue : Colors.transparent, width: 1.5),
      ),
      child: Stack(children: [
        // 표 비율만큼 차오르는 배경
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: share),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, f, _) => FractionallySizedBox(
                widthFactor: f.clamp(0, 1),
                heightFactor: 1,
                child: ColoredBox(color: AppColors.blue.withValues(alpha: leading ? 0.18 : 0.09)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 20, color: picked ? AppColors.blue : AppColors.gray),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: tt.bodyLarge!.copyWith(fontWeight: leading ? FontWeight.w700 : null)),
              ),
              Text('$count명', style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.w600)),
            ]),
            if (names.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(names.join(', '), style: tt.bodySmall),
              ),
          ]),
        ),
      ]),
    );
    return onTap == null ? row : Pressable(onTap: onTap!, child: row);
  }
}

// ───────────────────────── 공지 쓰기 ─────────────────────────

class NoticeEditor extends StatefulWidget {
  const NoticeEditor({super.key});

  @override
  State<NoticeEditor> createState() => _NoticeEditorState();
}

class _NoticeEditorState extends State<NoticeEditor> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _hasPoll = false;
  bool _multi = false;
  DateTime? _deadline;
  final List<TextEditingController> _options = [];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption([String text = '']) => setState(() => _options.add(TextEditingController(text: text)));

  Future<void> _addDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) _addOption('${monthDay(d)} (${weekday(d)})');
  }

  Future<void> _save() async {
    final s = AppScope.of(context);
    final me = s.me;
    final title = _title.text.trim();
    final options = [for (final c in _options) if (c.text.trim().isNotEmpty) c.text.trim()];
    String? problem;
    if (title.isEmpty) problem = '제목을 넣어주세요';
    if (_hasPoll && options.length < 2) problem = '투표 항목을 2개 이상 넣어주세요';
    if (me == null) problem = '가입 승인 후 쓸 수 있어요';
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await s.repo.postNotice(Notice(
        id: '',
        authorId: me!.id,
        authorName: me.name,
        title: title,
        body: _body.text.trim(),
        createdAt: DateTime.now(),
        poll: _hasPoll
            ? Poll(
                options: options,
                multi: _multi,
                // 고른 날 하루 끝까지 받아요.
                deadline: _deadline == null ? null : DateTime(_deadline!.year, _deadline!.month, _deadline!.day + 1),
              )
            : null,
      ));
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('올리지 못했어요: $e')));
      return;
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.pop(context);
    showDone(messenger, '공지를 올렸어요');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    Widget smallButton(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: BorderSide.none,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(icon, size: 18),
            label: Text(label),
            onPressed: onTap,
          ),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('새 공지', style: tt.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextField(controller: _title, decoration: const InputDecoration(hintText: '제목 (예: 12월 정기모임 날짜)')),
          const SizedBox(height: 10),
          TextField(
            controller: _body,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(hintText: '내용 (선택)'),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('투표 붙이기'),
              subtitle: const Text('날짜·장소 등을 골라요'),
              value: _hasPoll,
              onChanged: (v) => setState(() {
                _hasPoll = v;
                if (v && _options.isEmpty) {
                  _addOption();
                  _addOption();
                }
              }),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_hasPoll
                ? const SizedBox(width: double.infinity)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SizedBox(height: 12),
                    CupertinoSlidingSegmentedControl<bool>(
                      groupValue: _multi,
                      onValueChanged: (v) => setState(() => _multi = v!),
                      children: const {
                        false: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('하나만 고르기')),
                        true: Text('여러 개 고르기'),
                      },
                    ),
                    const SizedBox(height: 12),
                    for (final (i, c) in _options.indexed)
                      Padding(
                        key: ObjectKey(c),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: c,
                          decoration: InputDecoration(
                            hintText: '항목 ${i + 1} (날짜나 장소)',
                            suffixIcon: IconButton(
                              tooltip: '항목 빼기',
                              icon: const Icon(Icons.remove_circle_rounded, color: AppColors.red),
                              onPressed: () => setState(() => _options.removeAt(i).dispose()),
                            ),
                          ),
                        ),
                      ),
                    Row(children: [
                      smallButton(Icons.event_rounded, '날짜 추가', _addDate),
                      const SizedBox(width: 10),
                      smallButton(Icons.add_rounded, '항목 추가', _addOption),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: Text('마감일', style: tt.bodyMedium)),
                      if (_deadline != null)
                        TextButton(onPressed: () => setState(() => _deadline = null), child: const Text('없애기')),
                      TextButton(
                        onPressed: () async {
                          final now = DateUtils.dateOnly(DateTime.now());
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _deadline ?? now.add(const Duration(days: 3)),
                            firstDate: now,
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _deadline = d);
                        },
                        child: Text(_deadline == null ? '없음 (총무가 마감)' : '${monthDay(_deadline!)}까지'),
                      ),
                    ]),
                  ]),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? '올리는 중…' : '올리기')),
        ]),
      ),
    );
  }
}
