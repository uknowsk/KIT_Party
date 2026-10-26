import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/sheet.dart';
import '../format.dart';

/// 총무가 입출금 기록을 추가·수정하는 시트.
Future<void> showTxnEditor(BuildContext context, {Txn? preset}) => showAppSheet(context, (_) => TxnEditor(preset: preset), scrollable: false);

class TxnEditor extends StatefulWidget {
  const TxnEditor({super.key, this.preset});

  final Txn? preset;

  @override
  State<TxnEditor> createState() => _TxnEditorState();
}

class _TxnEditorState extends State<TxnEditor> {
  late TxnType _type = widget.preset?.type ?? TxnType.expense;
  late String _category = widget.preset?.category ?? Categories.of(_type).first;
  late DateTime _date = widget.preset?.date ?? DateUtils.dateOnly(DateTime.now());
  late String? _memberId = widget.preset?.memberId;
  late final _item = TextEditingController(text: widget.preset?.item ?? '');
  late final _amount = TextEditingController(
    text: (widget.preset?.amount ?? 0) > 0 ? '${widget.preset!.amount}' : '',
  );
  late final _memo = TextEditingController(text: widget.preset?.memo ?? '');
  bool _saving = false;

  bool get _isEdit => (widget.preset?.id ?? '').isNotEmpty;

  @override
  void dispose() {
    _item.dispose();
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    final item = _item.text.trim().isEmpty ? _category : _item.text.trim();
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('금액을 넣어주세요')));
      return;
    }
    setState(() => _saving = true);
    final s = AppScope.of(context);
    await s.repo.saveTxn(Txn(
      id: widget.preset?.id ?? '',
      date: _date,
      type: _type,
      category: _category,
      item: item,
      amount: amount,
      memberId: _memberId,
      memo: _memo.text.trim().isEmpty ? null : _memo.text.trim(),
      receiptUrl: widget.preset?.receiptUrl,
    ));
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white),
        const SizedBox(width: 8),
        Text(_isEdit ? '수정했어요' : '저장했어요'),
      ]),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_isEdit ? '기록 수정' : '새 기록', style: tt.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          CupertinoSlidingSegmentedControl<TxnType>(
            groupValue: _type,
            onValueChanged: (v) => setState(() {
              _type = v!;
              if (!Categories.of(_type).contains(_category)) _category = Categories.of(_type).first;
            }),
            children: const {
              TxnType.income: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('수입')),
              TxnType.expense: Text('지출'),
            },
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in Categories.of(_type))
              ChoiceChip(
                label: Text(c),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: tt.headlineMedium,
            decoration: const InputDecoration(hintText: '0', suffixText: '원'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _item, decoration: const InputDecoration(hintText: '항목 (예: 1차, 숙박, 세이프박스 이자)')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: BorderSide.none,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: Text('${_date.year}년 ${monthDay(_date)}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _memberId,
                isExpanded: true,
                decoration: const InputDecoration(hintText: '관련 회원'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('관련 회원 없음')),
                  for (final m in s.members) DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: (v) => setState(() => _memberId = v),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _memo, decoration: const InputDecoration(hintText: '메모 (선택)')),
          const SizedBox(height: 10),
          Text('영수증 사진 첨부는 다음 단계에서 붙어요.', style: tt.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? '저장 중…' : '저장')),
        ]),
      ),
    );
  }
}
