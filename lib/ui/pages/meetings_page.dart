import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/meeting_math.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/sheet.dart';
import 'ledger_page.dart';

enum _View { list, attendance }

/// 모임 탭: 장소 로테이션, 모임 기록, 참석률.
class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  var _view = _View.list;
  MeetingKind? _kind;
  int? _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    return LargeTitlePage(
      title: '모임',
      floating: s.canManageEvents
          ? FloatingActionButton(
              tooltip: '모임 기록하기',
              onPressed: () => showMeetingEditor(context),
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      slivers: [
        if (s.rulesOutdated && s.canManageEvents) const SliverToBoxAdapter(child: RulesBanner()),
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: RotationCard())),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: CupertinoSlidingSegmentedControl<_View>(
              groupValue: _view,
              onValueChanged: (v) => setState(() => _view = v!),
              children: const {
                _View.list: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('모임 기록')),
                _View.attendance: Text('참석률'),
              },
            ),
          ),
        ),
        if (_view == _View.list)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: s.meetings.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          s.canManageEvents ? '아직 모임 기록이 없어요. + 버튼으로 남겨 보세요.' : '아직 모임 기록이 없어요.',
                          style: tt.bodyMedium,
                        ),
                      )
                    : Column(children: [
                        for (final (i, m) in s.meetings.indexed)
                          FadeSlideIn(
                            key: ValueKey(m.id),
                            index: i,
                            child: _MeetingTile(meeting: m, total: s.members.length),
                          ),
                      ]),
              ),
            ),
          )
        else
          SliverToBoxAdapter(child: _attendance(context, s)),
      ],
    );
  }

  Widget _attendance(BuildContext context, AppState s) {
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    var firstYear = now.year;
    for (final m in s.meetings) {
      if (m.date.year < firstYear) firstYear = m.date.year;
    }
    final rows = MeetingMath.attendance(s.members, s.meetings, kind: _kind, year: _year);
    final total = rows.isEmpty ? 0 : rows.first.total;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PeriodStepper(
        label: _year == null ? '전체 기간' : '$_year년',
        // 맨 앞 해에서 한 번 더 누르면 '전체 기간'
        onPrev: _year == null
            ? null
            : () => setState(() => _year = _year! > firstYear ? _year! - 1 : null),
        onNext: _year == now.year ? null : () => setState(() => _year = _year == null ? firstYear : _year! + 1),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _kind == null ? 0 : _kind!.index + 1,
          onValueChanged: (v) => setState(() => _kind = v == 0 ? null : MeetingKind.values[v! - 1]),
          children: const {
            0: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('전체')),
            1: Text('정기모임'),
            2: Text('번개'),
          },
        ),
      ),
      SectionHeader('모임 $total번', trailing: Text('참석 횟수 · 참석률', style: tt.labelMedium)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppCard(
          child: total == 0
              ? Text('이 기간엔 모임 기록이 없어요', style: tt.bodyMedium)
              : Column(children: [
                  for (final (i, a) in rows.indexed)
                    Padding(
                      key: ValueKey('att_${a.member.id}'),
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                      child: Row(children: [
                        SizedBox(
                          width: 22,
                          child: Text('${i + 1}', style: tt.bodySmall, textAlign: TextAlign.center),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 56, child: Text(a.member.name, style: tt.bodyMedium, maxLines: 1)),
                        const SizedBox(width: 8),
                        Expanded(child: _Bar(value: a.rate, color: _rateColor(a.rate), delay: i)),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 74,
                          child: Text(
                            '${a.attended}/${a.total} · ${a.percent}%',
                            textAlign: TextAlign.right,
                            style: tt.bodySmall!.copyWith(
                              color: tt.bodyMedium!.color,
                              fontFeatures: const [FontFeature.tabularFigures()],
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

Color _rateColor(double r) => r >= .75 ? AppColors.green : (r >= .4 ? AppColors.blue : AppColors.orange);

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, this.delay = 0});

  final double value;
  final Color color;
  final int delay;

  @override
  Widget build(BuildContext context) => Container(
        height: 8,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: Duration(milliseconds: 600 + 50 * delay.clamp(0, 10)),
          curve: Curves.easeOutCubic,
          builder: (_, f, _) => FractionallySizedBox(
            widthFactor: f,
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ),
      );
}

/// 서버 보안 규칙을 새로 붙여넣어야 할 때 총무에게만 보이는 안내.
class RulesBanner extends StatelessWidget {
  const RulesBanner({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: AppCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lock_clock_rounded, color: AppColors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '모임·공지를 쓰려면 Firebase 보안 규칙을 새로 붙여넣어야 해요. (한 번만)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ]),
        ),
      );
}

// ───────────────────────── 장소 로테이션 ─────────────────────────

class RotationCard extends StatelessWidget {
  const RotationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final order = s.settings!.rotation;
    final next = MeetingMath.nextRegion(order, s.meetings);
    final visits = MeetingMath.lastVisits(s.meetings);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('정기모임 장소 순서', style: tt.labelMedium)),
          if (s.isTreasurer)
            GestureDetector(
              onTap: () => showAppSheet(context, (_) => const _RotationEditor(), scrollable: false),
              child: Text('순서 바꾸기', style: tt.labelMedium!.copyWith(color: AppColors.blue)),
            ),
        ]),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: '다음은 '),
            TextSpan(text: next, style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700)),
            const TextSpan(text: ' 차례'),
          ]),
          key: const Key('nextRegion'),
          style: tt.titleLarge,
        ),
        const SizedBox(height: 14),
        Row(children: [
          for (final (i, r) in order.indexed) ...[
            if (i > 0) const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.gray),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: r == next ? AppColors.blue : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  FittedBox(
                    child: Text(
                      r,
                      style: tt.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: r == next ? Colors.white : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    visits[r] == null ? '–' : '${visits[r]!.year % 100}.${visits[r]!.month}',
                    style: tt.bodySmall!.copyWith(fontSize: 11, color: r == next ? Colors.white70 : null),
                  ),
                ]),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _RotationEditor extends StatefulWidget {
  const _RotationEditor();

  @override
  State<_RotationEditor> createState() => _RotationEditorState();
}

class _RotationEditorState extends State<_RotationEditor> {
  late final List<String> _order = [...AppScope.of(context).settings!.rotation];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('장소 순서 바꾸기', style: tt.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('오른쪽 손잡이를 끌어서 옮겨요', style: tt.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (a, b) => setState(() => _order.insert(b, _order.removeAt(a))),
            children: [
              for (final (i, r) in _order.indexed)
                ListTile(
                  key: ValueKey(r),
                  leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: tt.labelMedium)),
                  title: Text(r),
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle_rounded),
                  ),
                ),
            ],
          ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            final s = AppScope.of(context);
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(context);
            await s.repo.setRotation(_order);
            showDone(messenger, '순서를 바꿨어요');
          },
          child: const Text('저장'),
        ),
      ]),
    );
  }
}

// ───────────────────────── 모임 기록 ─────────────────────────

class _MeetingTile extends StatelessWidget {
  const _MeetingTile({required this.meeting, required this.total});

  final Meeting meeting;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final m = meeting;
    final color = m.isRegular ? const Color(0xFF5856D6) : AppColors.orange;
    final where = [?m.region, if (m.place.isNotEmpty) m.place].join(' · ');
    return Pressable(
      onTap: () => showMeetingDetail(context, m),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(m.isRegular ? Icons.groups_rounded : Icons.bolt_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Badge2(m.kind.label, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${m.date.year}. ${monthDay(m.date)}',
                    style: tt.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
              if (where.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(where, style: tt.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          Text('${m.attendeeIds.length}/$total명', style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

Future<void> showMeetingDetail(BuildContext context, Meeting m) => showAppSheet(
      context,
      (_) => Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), child: _MeetingDetail(meeting: m)),
    );

class _MeetingDetail extends StatelessWidget {
  const _MeetingDetail({required this.meeting});

  final Meeting meeting;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final m = meeting;
    final came = [for (final mem in s.members) if (m.attendeeIds.contains(mem.id)) mem];
    final missed = [for (final mem in s.members) if (!m.attendeeIds.contains(mem.id)) mem];
    Widget names(List<Member> list, Color color) => Wrap(spacing: 6, runSpacing: 6, children: [
          for (final mem in list) Badge2(mem.name, color: color),
        ]);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(m.kind.label, style: tt.labelMedium, textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text('${m.date.year}년 ${monthDay(m.date)} (${weekday(m.date)})', style: tt.titleLarge, textAlign: TextAlign.center),
      if (m.region != null || m.place.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text([?m.region, if (m.place.isNotEmpty) m.place].join(' · '),
            style: tt.bodyMedium, textAlign: TextAlign.center),
      ],
      const SizedBox(height: 16),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('참석 ${came.length}명', style: tt.labelMedium),
          const SizedBox(height: 8),
          if (came.isEmpty) Text('없음', style: tt.bodyMedium) else names(came, AppColors.blue),
          if (missed.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('불참 ${missed.length}명', style: tt.labelMedium),
            const SizedBox(height: 8),
            names(missed, AppColors.gray),
          ],
        ]),
      ),
      if (m.memo?.isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        AppCard(child: Text(m.memo!, style: tt.bodyMedium)),
      ],
      if (s.canManageEvents) ...[
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
                if (await confirm(context, '이 모임 기록을 지울까요?', '참석 기록도 함께 지워져요.') && context.mounted) {
                  Navigator.pop(context);
                  await s.repo.deleteMeeting(m.id);
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
                Navigator.pop(context);
                showMeetingEditor(context, preset: m);
              },
              child: const Text('수정'),
            ),
          ),
        ]),
      ],
    ]);
  }
}

Future<void> showMeetingEditor(BuildContext context, {Meeting? preset}) =>
    showAppSheet(context, (_) => MeetingEditor(preset: preset), scrollable: false);

class MeetingEditor extends StatefulWidget {
  const MeetingEditor({super.key, this.preset});

  final Meeting? preset;

  @override
  State<MeetingEditor> createState() => _MeetingEditorState();
}

class _MeetingEditorState extends State<MeetingEditor> {
  late MeetingKind _kind = widget.preset?.kind ?? MeetingKind.regular;
  late DateTime _date = widget.preset?.date ?? DateUtils.dateOnly(DateTime.now());
  late String? _region = widget.preset != null
      ? widget.preset!.region
      : MeetingMath.nextRegion(AppScope.of(context).settings!.rotation, AppScope.of(context).meetings);
  late final Set<String> _who = {...?widget.preset?.attendeeIds};
  late final _place = TextEditingController(text: widget.preset?.place ?? '');
  late final _memo = TextEditingController(text: widget.preset?.memo ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _place.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppScope.of(context);
    if (_kind == MeetingKind.regular && _region == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('정기모임 지역을 골라주세요')));
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await s.repo.saveMeeting(Meeting(
        id: widget.preset?.id ?? '',
        date: _date,
        kind: _kind,
        region: _region,
        place: _place.text.trim(),
        // 명단 순서대로 저장
        attendeeIds: [for (final m in s.members) if (_who.contains(m.id)) m.id],
        memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
      ));
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('저장 못 했어요: $e')));
      return;
    }
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.pop(context);
    showDone(messenger, widget.preset == null ? '모임을 기록했어요' : '수정했어요');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final allIn = _who.length == s.members.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.preset == null ? '모임 기록' : '모임 수정', style: tt.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          CupertinoSlidingSegmentedControl<MeetingKind>(
            groupValue: _kind,
            onValueChanged: (v) => setState(() => _kind = v!),
            children: const {
              MeetingKind.regular: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('정기모임')),
              MeetingKind.flash: Text('번개'),
            },
          ),
          const SizedBox(height: 12),
          DateButton(date: _date, onPicked: (d) => setState(() => _date = d)),
          const SizedBox(height: 12),
          Text('지역', style: tt.labelMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in s.settings!.rotation)
              ChoiceChip(label: Text(r), selected: _region == r, onSelected: (_) => setState(() => _region = r)),
            if (_kind == MeetingKind.flash)
              ChoiceChip(label: const Text('안 정함'), selected: _region == null, onSelected: (_) => setState(() => _region = null)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _place, decoration: const InputDecoration(hintText: '장소 (예: 대전 유성 ○○식당)')),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('참석자 ${_who.length}명', style: tt.labelMedium)),
            GestureDetector(
              onTap: () => setState(() => allIn ? _who.clear() : _who.addAll(s.members.map((m) => m.id))),
              child: Text(allIn ? '모두 빼기' : '모두 넣기', style: tt.labelMedium!.copyWith(color: AppColors.blue)),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in s.members)
              FilterChip(
                label: Text(m.name),
                selected: _who.contains(m.id),
                onSelected: (on) => setState(() => on ? _who.add(m.id) : _who.remove(m.id)),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _memo, decoration: const InputDecoration(hintText: '메모 (선택)')),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? '저장 중…' : '저장')),
        ]),
      ),
    );
  }
}
