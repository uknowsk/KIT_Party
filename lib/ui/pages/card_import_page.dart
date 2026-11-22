import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../cards/card_inbox.dart';
import '../../cards/card_parser.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'txn_editor.dart';

/// 카드 결제 가져오기 화면 열기 (총무만).
Future<void> openCardImport(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute(builder: AppScope.carry(context, (_) => const CardImportPage())),
    );

/// 어떤 날의 결제를 볼까요?
enum CardPeriod {
  meetings('모임 날만'),
  recent('최근 30일'),
  custom('기간 고르기');

  const CardPeriod(this.label);
  final String label;
}

/// 총무 폰의 카드 결제 문자·알림 → 지출 후보 → 확인 후 장부에 저장.
class CardImportPage extends StatefulWidget {
  const CardImportPage({super.key, this.preload});

  /// 테스트용: 폰 대신 넣어줄 결제 목록.
  final List<CardCharge>? preload;

  @override
  State<CardImportPage> createState() => _CardImportPageState();
}

class _CardImportPageState extends State<CardImportPage> with WidgetsBindingObserver {
  bool _loading = true;
  bool _smsOk = false;
  bool _notiOk = false;
  List<CardCharge> _all = const [];
  Set<String> _cards = {};
  Set<String> _handled = {};
  final Set<String> _picked = {};
  var _period = CardPeriod.meetings;
  DateTimeRange? _range;
  bool _showHandled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 설정 화면에서 돌아오면 권한을 다시 확인해요.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  DateTimeRange get _loadRange {
    final now = DateTime.now();
    return switch (_period) {
      CardPeriod.recent => DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      CardPeriod.meetings => DateTimeRange(start: now.subtract(const Duration(days: 120)), end: now),
      CardPeriod.custom => _range ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    };
  }

  Future<void> _refresh() async {
    if (widget.preload != null) {
      setState(() {
        _all = widget.preload!;
        _smsOk = true;
        _notiOk = true;
        _loading = false;
      });
      return;
    }
    final sms = await CardInbox.smsGranted();
    final noti = await CardInbox.notiEnabled();
    final r = _loadRange;
    final list = await CardInbox.load(r.start, DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59));
    final cards = await CardInbox.chosenCards();
    final handled = await CardInbox.handled();
    if (!mounted) return;
    setState(() {
      _smsOk = sms;
      _notiOk = noti;
      _all = list;
      _cards = cards;
      _handled = handled;
      _loading = false;
    });
  }

  /// 이 결제가 어느 모임 것인지 (모임 날, 또는 다음 날 새벽 6시 전까지).
  Meeting? _meetingOf(CardCharge c, List<Meeting> meetings) {
    for (final m in meetings) {
      final d = DateTime(m.date.year, m.date.month, m.date.day);
      final until = d.add(const Duration(days: 1, hours: 6));
      if (!c.time.isBefore(d) && c.time.isBefore(until)) return m;
    }
    return null;
  }

  bool _hasSimilar(CardCharge c, List<Txn> txns) => txns.any((t) =>
      !t.isIncome &&
      t.amount == c.amount &&
      t.date.difference(DateTime(c.time.year, c.time.month, c.time.day)).inDays.abs() <= 1);

  Txn _draft(CardCharge c, AppState s) {
    final m = _meetingOf(c, s.meetings);
    final merchant = c.merchant.isEmpty ? '카드 결제' : c.merchant;
    final memo = '${c.cardLabel} ${clock(c.time)}${c.installment > 0 ? ' · ${c.installment}개월 할부' : ''}';
    if (c.isCancel) {
      return Txn(
        id: '',
        date: DateUtils.dateOnly(c.time),
        type: TxnType.income,
        category: Categories.otherIncome,
        item: '$merchant 결제취소',
        amount: c.amount,
        memo: memo,
      );
    }
    return Txn(
      id: '',
      date: DateUtils.dateOnly(c.time),
      type: TxnType.expense,
      category: m?.kind.label ?? guessCategory(merchant, Categories.expense),
      item: merchant,
      amount: c.amount,
      memo: memo,
    );
  }

  List<CardCharge> _visible(AppState s) => _all.where((c) {
        if (_cards.isNotEmpty && !_cards.contains(c.cardLabel)) return false;
        if (!_showHandled && _handled.contains(c.key)) return false;
        if (_period == CardPeriod.meetings && _meetingOf(c, s.meetings) == null) return false;
        if (_period == CardPeriod.custom && _range != null) {
          final end = _range!.end.add(const Duration(days: 1));
          if (c.time.isBefore(_range!.start) || !c.time.isBefore(end)) return false;
        }
        return true;
      }).toList();

  Future<void> _toggleCard(String label, List<String> allLabels) async {
    setState(() {
      // 처음 누르면 "그 카드만" 으로 시작해요.
      if (_cards.isEmpty) {
        _cards = {label};
      } else if (_cards.contains(label)) {
        _cards = {..._cards}..remove(label);
      } else {
        _cards = {..._cards, label};
      }
      if (_cards.length == allLabels.length) _cards = {};
    });
    HapticFeedback.selectionClick();
    await CardInbox.setChosenCards(_cards);
  }

  Future<void> _hide(CardCharge c) async {
    setState(() {
      _handled = {..._handled, c.key};
      _picked.remove(c.key);
    });
    await CardInbox.markHandled([c.key]);
  }

  Future<void> _unhide(CardCharge c) async {
    setState(() => _handled = {..._handled}..remove(c.key));
    await CardInbox.unmarkHandled(c.key);
  }

  Future<void> _openOne(CardCharge c) async {
    final s = AppScope.of(context);
    final saved = await showTxnEditor(context, preset: _draft(c, s));
    if (saved) {
      setState(() {
        _handled = {..._handled, c.key};
        _picked.remove(c.key);
      });
      await CardInbox.markHandled([c.key]);
    }
  }

  Future<void> _saveSelected(List<CardCharge> visible) async {
    final s = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final chosen = visible.where((c) => _picked.contains(c.key)).toList();
    if (chosen.isEmpty) return;
    setState(() => _saving = true);
    try {
      for (final c in chosen) {
        await s.repo.saveTxn(_draft(c, s));
      }
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          _handled = {..._handled, ...chosen.map((c) => c.key)};
          _picked.clear();
        });
      }
      showDone(messenger, '${chosen.length}건 장부에 올렸어요');
      await CardInbox.markHandled(chosen.map((c) => c.key));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('저장하지 못했어요: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _range ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (r == null) return;
    setState(() {
      _range = r;
      _period = CardPeriod.custom;
      _loading = true;
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    final visible = _visible(s);
    final labels = {for (final c in _all) c.cardLabel, ..._cards}.toList()..sort();
    final pickedCount = visible.where((c) => _picked.contains(c.key)).length;
    final ready = _smsOk || _notiOk;

    return Scaffold(
      appBar: AppBar(title: const Text('카드 결제 가져오기')),
      bottomNavigationBar: pickedCount == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  key: const Key('cardSaveSelected'),
                  onPressed: _saving ? null : () => _saveSelected(visible),
                  child: Text(_saving ? '올리는 중…' : '선택한 $pickedCount건 장부에 올리기'),
                ),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (!CardInbox.supported && widget.preload == null)
              const _Info('안드로이드 폰에서만 쓸 수 있어요.'),
            // ── 켜기 ──
            if (!_smsOk || !_notiOk) ...[
              const SectionHeader('켜기 (둘 중 하나만 켜도 돼요)'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _SetupRow(
                      icon: Icons.sms_rounded,
                      title: '카드 결제 문자 읽기',
                      body: '카드사가 보낸 승인 문자에서 금액·가게를 읽어요.',
                      on: _smsOk,
                      onTap: () async {
                        final ok = await CardInbox.requestSms();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('권한이 꺼져 있어요. 앱 설정 > 권한 > SMS 에서 켜주세요.'),
                            action: SnackBarAction(label: '설정 열기', onPressed: CardInbox.openAppSettings),
                          ));
                        }
                        _refresh();
                      },
                    ),
                    const Divider(height: 0.5, indent: 56),
                    _SetupRow(
                      icon: Icons.notifications_active_rounded,
                      title: '카드 앱 알림 모으기',
                      body: '카드 앱·카카오 알림톡으로 오는 결제 알림을 모아요. 켠 뒤부터 쌓여요.',
                      on: _notiOk,
                      onTap: () => _confirmNoti(context),
                    ),
                  ]),
                ),
              ),
              const _Info('문자·알림은 이 폰 안에서만 읽어요. 총무가 고른 결제만 장부에 올라가요.'),
            ],
            if (ready) ...[
              // ── 기간 ──
              const SectionHeader('어떤 날 결제?'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoSlidingSegmentedControl<CardPeriod>(
                  key: const Key('cardPeriod'),
                  groupValue: _period,
                  onValueChanged: (v) {
                    if (v == CardPeriod.custom) {
                      _pickRange();
                      return;
                    }
                    setState(() {
                      _period = v!;
                      _loading = true;
                    });
                    _refresh();
                  },
                  children: {
                    for (final p in CardPeriod.values)
                      p: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(p == CardPeriod.custom && _range != null
                            ? '${_range!.start.month}/${_range!.start.day}~${_range!.end.month}/${_range!.end.day}'
                            : p.label),
                      ),
                  },
                ),
              ),
              if (_period == CardPeriod.meetings)
                _Info(s.meetings.isEmpty
                    ? '모임 탭에 모임 날짜를 넣으면, 그날(새벽 6시까지) 결제만 골라 보여드려요.'
                    : '모임 탭에 기록한 날(다음 날 새벽 6시까지) 결제만 보여요.'),
              // ── 카드 ──
              if (labels.isNotEmpty) ...[
                SectionHeader('어떤 카드?', trailing: _cards.isEmpty ? null : _TextBtn('전부', () async {
                  setState(() => _cards = {});
                  await CardInbox.setChosenCards({});
                })),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final l in labels)
                      FilterChip(
                        label: Text(l),
                        selected: _cards.isEmpty || _cards.contains(l),
                        onSelected: (_) => _toggleCard(l, labels),
                      ),
                  ]),
                ),
                const _Info('회비 카드만 골라두면 다음에도 그 카드만 보여요.'),
              ],
              // ── 목록 ──
              SectionHeader(
                _loading ? '불러오는 중…' : '결제 ${visible.length}건',
                trailing: visible.isEmpty
                    ? null
                    : _TextBtn(pickedCount == visible.where((c) => !_handled.contains(c.key)).length && pickedCount > 0 ? '선택 해제' : '전체 선택', () {
                        setState(() {
                          final open = visible.where((c) => !_handled.contains(c.key)).map((c) => c.key);
                          if (open.every(_picked.contains)) {
                            _picked.removeAll(open);
                          } else {
                            _picked.addAll(open);
                          }
                        });
                      }),
              ),
              if (!_loading && visible.isEmpty)
                const _Info('보여드릴 결제가 없어요. 기간이나 카드를 바꿔보세요.'),
              for (final c in visible)
                _ChargeTile(
                  charge: c,
                  draft: _draft(c, s),
                  similar: _hasSimilar(c, s.txns),
                  handled: _handled.contains(c.key),
                  picked: _picked.contains(c.key),
                  onPick: (v) => setState(() => v ? _picked.add(c.key) : _picked.remove(c.key)),
                  onOpen: () => _openOne(c),
                  onHide: () => _hide(c),
                  onUnhide: () => _unhide(c),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  Expanded(child: Text('올렸거나 숨긴 결제도 보기', style: tt.bodyMedium)),
                  CupertinoSwitch(value: _showHandled, onChanged: (v) => setState(() => _showHandled = v)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmNoti(BuildContext context) async {
    final go = await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('알림 접근을 켤게요'),
        content: const Text('다음 화면에서 "회비장부"를 찾아 켜주세요.\n결제 알림만 골라 이 폰에만 저장해요.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(c, false), child: const Text('나중에')),
          CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.pop(c, true), child: const Text('열기')),
        ],
      ),
    );
    if (go == true) await CardInbox.openNotiSettings();
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({required this.icon, required this.title, required this.body, required this.on, required this.onTap});

  final IconData icon;
  final String title;
  final String body;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(children: [
        Icon(icon, color: AppColors.blue),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: tt.titleMedium),
            const SizedBox(height: 2),
            Text(body, style: tt.bodySmall!.copyWith(color: AppColors.gray)),
          ]),
        ),
        const SizedBox(width: 8),
        on
            ? const Badge2('켜짐', color: AppColors.green)
            : FilledButton.tonal(onPressed: onTap, child: const Text('켜기')),
      ]),
    );
  }
}

class _ChargeTile extends StatelessWidget {
  const _ChargeTile({
    required this.charge,
    required this.draft,
    required this.similar,
    required this.handled,
    required this.picked,
    required this.onPick,
    required this.onOpen,
    required this.onHide,
    required this.onUnhide,
  });

  final CardCharge charge;
  final Txn draft;
  final bool similar;
  final bool handled;
  final bool picked;
  final ValueChanged<bool> onPick;
  final VoidCallback onOpen;
  final VoidCallback onHide;
  final VoidCallback onUnhide;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final c = charge;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Opacity(
        opacity: handled ? 0.5 : 1,
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
          onTap: handled ? onUnhide : onOpen,
          child: Row(children: [
            Checkbox(
              value: picked,
              onChanged: handled ? null : (v) => onPick(v ?? false),
              shape: const CircleBorder(),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.merchant.isEmpty ? '가게 이름 없음' : c.merchant,
                    style: tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('${c.cardLabel} · ${clock(c.time)}${c.source == 'noti' ? ' · 앱알림' : ''}',
                    style: tt.bodySmall!.copyWith(color: AppColors.gray)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  Badge2(draft.category, color: categoryColor(draft.category)),
                  if (c.isCancel) const Badge2('결제취소', color: AppColors.red),
                  if (c.installment > 0) Badge2('${c.installment}개월 할부', color: AppColors.orange),
                  if (similar && !handled) const Badge2('장부에 비슷한 기록 있음', color: AppColors.orange),
                  if (handled) const Badge2('올림/숨김 · 누르면 되돌려요', color: AppColors.gray),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Text(
              '${c.isCancel ? '+' : '−'}${won(c.amount)}',
              style: tt.titleMedium!.copyWith(color: c.isCancel ? AppColors.green : null),
            ),
            if (!handled)
              IconButton(
                tooltip: '숨기기',
                onPressed: onHide,
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.gray),
              )
            else
              const SizedBox(width: 12),
          ]),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.gray)),
      );
}

class _TextBtn extends StatelessWidget {
  const _TextBtn(this.text, this.onTap);

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text(text, style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
      );
}
