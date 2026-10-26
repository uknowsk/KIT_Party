import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ledger_page.dart';

/// 회원 누구나 글을 남기는 곳.
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = AppScope.of(context);
    final me = s.me;
    final text = _text.text.trim();
    if (me == null || text.isEmpty) return;
    _text.clear();
    HapticFeedback.lightImpact();
    await s.repo.postMessage(Message(
      id: '',
      authorId: me.id,
      authorName: me.name,
      text: text,
      createdAt: DateTime.now(),
    ));
  }

  void _actions(Message m) {
    final s = AppScope.of(context);
    final mine = m.authorId == s.me?.id;
    if (!mine && !s.isTreasurer) return;
    HapticFeedback.selectionClick();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        actions: [
          if (s.isTreasurer)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(c);
                s.repo.setPinned(m.id, !m.pinned);
              },
              child: Text(m.pinned ? '공지 내리기' : '공지로 고정'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(c);
              if (await confirm(context, '메시지를 지울까요?', '지우면 되돌릴 수 없어요.')) {
                await s.repo.deleteMessage(m.id);
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
    final pinned = s.messages.where((m) => m.pinned).toList();
    final items = s.messages.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('메시지')),
      body: Column(children: [
        if (pinned.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.campaign_rounded, color: AppColors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(pinned.last.text, style: tt.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final m = items[i];
              final mine = m.authorId == s.me?.id;
              return FadeSlideIn(
                key: ValueKey(m.id),
                index: 0,
                child: _Bubble(message: m, mine: mine, onLongPress: () => _actions(m)),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  enabled: s.me != null,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: s.me == null ? '가입 승인 후 쓸 수 있어요' : '메시지 보내기',
                    counterText: '',
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ValueListenableBuilder(
                valueListenable: _text,
                builder: (_, v, _) => AnimatedScale(
                  scale: v.text.trim().isEmpty ? 0.85 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: IconButton.filled(
                    onPressed: v.text.trim().isEmpty ? null : _send,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.onLongPress});

  final Message message;
  final bool mine;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        if (!mine)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 2),
            child: Text(message.authorName, style: tt.labelMedium),
          ),
        GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: mine ? cs.primary : cs.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(message.text, style: tt.bodyLarge!.copyWith(color: mine ? Colors.white : null)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Text(
            '${message.pinned ? '공지 · ' : ''}${clock(message.createdAt)}',
            style: tt.bodySmall!.copyWith(fontSize: 11),
          ),
        ),
      ]),
    );
  }
}
