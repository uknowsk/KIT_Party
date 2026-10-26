import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../format.dart';
import '../theme.dart';

/// 흰 둥근 카드.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap!, child: card);
  }
}

/// 누르면 살짝 작아졌다 돌아오는 효과.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _down ? 0.75 : 1,
            duration: const Duration(milliseconds: 120),
            child: widget.child,
          ),
        ),
      );
}

/// 숫자가 돌르륵 올라가며 나타나요.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style, this.suffix = '원'});

  final int value;
  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Text(
          '${won(v.round()).replaceAll('원', '')}$suffix',
          style: style,
          maxLines: 1,
        ),
      );
}

/// 목록이 아래에서 살짝 떠오르며 차례로 나타나요.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: 35 * widget.index.clamp(0, 10));
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a),
        child: widget.child,
      ),
    );
  }
}

/// 회색 작은 글씨의 구역 제목.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.labelMedium)),
          ?trailing,
        ]),
      );
}

class Badge2 extends StatelessWidget {
  const Badge2(this.text, {super.key, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );
}

IconData categoryIcon(String c) => switch (c) {
      '회비' => Icons.person_rounded,
      '이자' => Icons.savings_rounded,
      '정기모임' => Icons.groups_rounded,
      '번개' => Icons.bolt_rounded,
      '경조사' => Icons.local_florist_rounded,
      '생일선물' => Icons.cake_rounded,
      _ => Icons.more_horiz_rounded,
    };

Color categoryColor(String c) => switch (c) {
      '회비' => AppColors.blue,
      '이자' => AppColors.green,
      '정기모임' => const Color(0xFF5856D6),
      '번개' => AppColors.orange,
      '경조사' => const Color(0xFF8E8E93),
      '생일선물' => const Color(0xFFFF2D55),
      _ => const Color(0xFF64D2FF),
    };

/// 입출금 기록 한 줄.
class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, this.memberName, this.onTap, this.selected = false});

  final Txn txn;
  final String? memberName;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = categoryColor(txn.category);
    final title = memberName == null || txn.item == memberName
        ? txn.item
        : (txn.item == txn.category ? '$memberName ${txn.item}' : '${txn.item} · $memberName');
    final row = Container(
      color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(categoryIcon(txn.category), color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: tt.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${txn.category} · ${monthDay(txn.date)}', style: tt.bodySmall),
          ]),
        ),
        if (txn.receiptUrl != null) const Padding(
          padding: EdgeInsets.only(right: 6),
          child: Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.gray),
        ),
        Text(
          wonSigned(txn.signed),
          style: tt.bodyLarge!.copyWith(
            fontWeight: FontWeight.w600,
            color: txn.isIncome ? AppColors.green : null,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ]),
    );
    return onTap == null ? row : Pressable(onTap: onTap!, child: row);
  }
}

/// 큰 제목이 스크롤하면 작아지는 애플식 화면 틀.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({super.key, required this.title, required this.slivers, this.actions, this.floating});

  final String title;
  final List<Widget> slivers;
  final List<Widget>? actions;
  final Widget? floating;

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: floating,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // 가로로 눕히면 화면이 낮으니 큰 제목 대신 한 줄 제목.
            if (MediaQuery.sizeOf(context).height < 500)
              SliverAppBar(title: Text(title), pinned: true, actions: actions)
            else
              SliverAppBar.large(
                title: Text(title),
                centerTitle: false,
                actions: actions,
                expandedHeight: 112,
              ),
            ...slivers,
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      );
}
