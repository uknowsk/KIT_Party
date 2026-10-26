import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';
import 'common.dart';

/// 화면에 처음 보일 때 한 번 0→1로 흐르는 값. 그래프가 "그려지는" 효과에 써요.
/// 아래쪽에 있어 아직 안 보이면, 스크롤해서 보일 때 시작해요.
mixin _Reveal<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  Duration get revealDuration => const Duration(milliseconds: 1100);
  late final AnimationController reveal = AnimationController(vsync: this, duration: revealDuration);
  ScrollPosition? _scroll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scroll = Scrollable.maybeOf(context)?.position;
      _scroll?.addListener(_check);
      _check();
    });
  }

  void _check() {
    if (!mounted || reveal.status != AnimationStatus.dismissed) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.sizeOf(context).height - box.size.height * .35) {
      _scroll?.removeListener(_check);
      reveal.forward();
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_check);
    reveal.dispose();
    super.dispose();
  }
}

TextStyle _axis(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall!.copyWith(color: AppColors.gray, fontSize: 11);

/// 눌렀거나 끌고 있는 x 위치 → 몇 번째 칸인지.
int _slot(double dx, double width, int count) => (dx / width * count).floor().clamp(0, count - 1);

// ───────────────────────── 잔고 흐름 (선 그래프) ─────────────────────────

class BalanceTrendCard extends StatefulWidget {
  const BalanceTrendCard({super.key, required this.balances, required this.opening});

  /// 1월부터 달마다 말일 잔고.
  final List<int> balances;

  /// 시작 잔고 (그래프 맨 왼쪽 기준점).
  final int opening;

  @override
  State<BalanceTrendCard> createState() => _BalanceTrendCardState();
}

class _BalanceTrendCardState extends State<BalanceTrendCard> with SingleTickerProviderStateMixin, _Reveal {
  int? _picked;

  void _pick(Offset p, double w) => setState(() => _picked = _slot(p.dx, w, widget.balances.length));

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final b = widget.balances;
    final i = _picked ?? b.length - 1;
    final diff = b[i] - (i == 0 ? widget.opening : b[i - 1]);
    final diffColor = diff >= 0 ? AppColors.green : AppColors.red;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('잔고 흐름', style: tt.labelMedium),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Row(
            key: ValueKey(i),
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${i + 1}월 말 ', style: tt.bodySmall),
              Flexible(
                child: Text(won(b[i]),
                    style: tt.titleMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    maxLines: 1,
                    overflow: TextOverflow.fade),
              ),
              const SizedBox(width: 6),
              Text('${diff >= 0 ? '▲' : '▼'} ${won(diff.abs())}', style: tt.bodySmall!.copyWith(color: diffColor)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: LayoutBuilder(builder: (context, c) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _pick(d.localPosition, c.maxWidth),
              onHorizontalDragStart: (d) => _pick(d.localPosition, c.maxWidth),
              onHorizontalDragUpdate: (d) => _pick(d.localPosition, c.maxWidth),
              onHorizontalDragEnd: (_) => setState(() => _picked = null),
              onTapUp: (_) => Future.delayed(const Duration(milliseconds: 1200), () {
                if (mounted) setState(() => _picked = null);
              }),
              child: AnimatedBuilder(
                animation: reveal,
                builder: (context, _) => CustomPaint(
                  size: Size(c.maxWidth, 150),
                  painter: _LinePainter(
                    values: b,
                    progress: Curves.easeInOutCubic.transform(reveal.value),
                    picked: _picked,
                    color: Theme.of(context).colorScheme.primary,
                    grid: Theme.of(context).dividerColor,
                    surface: Theme.of(context).cardColor,
                    axis: _axis(context),
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.progress,
    required this.picked,
    required this.color,
    required this.grid,
    required this.surface,
    required this.axis,
  });

  final List<int> values;
  final double progress;
  final int? picked;
  final Color color;
  final Color grid;
  final Color surface;
  final TextStyle axis;

  static const _labelH = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    final h = size.height - _labelH;
    final slot = size.width / n;
    final lo = values.reduce(math.min).toDouble();
    final hi = values.reduce(math.max).toDouble();
    final pad = math.max((hi - lo) * 0.25, hi * 0.002 + 1);
    double y(int v) => 8 + (h - 16) * (1 - (v - (lo - pad)) / ((hi + pad) - (lo - pad)));
    final pts = [for (var i = 0; i < n; i++) Offset(slot * (i + .5), y(values[i]))];

    // 가로 보조선 3줄
    final gp = Paint()
      ..color = grid.withValues(alpha: .5)
      ..strokeWidth = .5;
    for (var k = 0; k < 3; k++) {
      final gy = 8 + (h - 16) * k / 2;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gp);
    }

    // 부드러운 곡선
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < n - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i], p2 = pts[i + 1];
      final p3 = i + 2 < n ? pts[i + 2] : p2;
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    final revealX = pts.first.dx + (pts.last.dx - pts.first.dx) * progress;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, revealX + 1, size.height));

    // 아래 그라디언트 면
    final area = Path.from(line)
      ..lineTo(pts.last.dx, h)
      ..lineTo(pts.first.dx, h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTRB(0, 0, size.width, h)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    // 고른 달 세로선
    final sel = picked ?? (progress >= 1 ? n - 1 : null);
    if (sel != null) {
      final p = pts[sel];
      if (picked != null) {
        canvas.drawLine(
            Offset(p.dx, 0),
            Offset(p.dx, h),
            Paint()
              ..color = color.withValues(alpha: .35)
              ..strokeWidth = 1);
      }
      canvas.drawCircle(p, 6, Paint()..color = surface);
      canvas.drawCircle(p, 4.5, Paint()..color = color);
    }

    // 아래 월 표시
    final every = n > 8 && size.width < 320 ? 2 : 1;
    for (var i = 0; i < n; i++) {
      if (i % every != 0 && i != n - 1) continue;
      final tp = TextPainter(
        text: TextSpan(text: '${i + 1}월', style: i == sel ? axis.copyWith(color: color) : axis),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pts[i].dx - tp.width / 2, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(_LinePainter o) =>
      o.progress != progress || o.picked != picked || o.values != values || o.color != color;
}

// ───────────────────────── 월별 수입·지출 (막대 그래프) ─────────────────────────

class MonthlyFlowCard extends StatefulWidget {
  const MonthlyFlowCard({super.key, required this.flows});

  /// 1월부터 달마다 (수입, 지출).
  final List<(int, int)> flows;

  @override
  State<MonthlyFlowCard> createState() => _MonthlyFlowCardState();
}

class _MonthlyFlowCardState extends State<MonthlyFlowCard> with SingleTickerProviderStateMixin, _Reveal {
  int? _picked;

  @override
  Duration get revealDuration => const Duration(milliseconds: 1300);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final f = widget.flows;
    final i = _picked ?? f.length - 1;
    Widget legend(Color c, String label, int v) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$label ', style: tt.bodySmall),
          Text(won(v), style: tt.bodySmall!.copyWith(fontWeight: FontWeight.w600, color: tt.bodyLarge!.color)),
        ]);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${i + 1}월 수입·지출', style: tt.labelMedium),
        const SizedBox(height: 6),
        Wrap(spacing: 14, runSpacing: 4, children: [
          legend(AppColors.green, '수입', f[i].$1),
          legend(AppColors.orange, '지출', f[i].$2),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: LayoutBuilder(builder: (context, c) {
            void pick(Offset p) => setState(() => _picked = _slot(p.dx, c.maxWidth, f.length));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => pick(d.localPosition),
              onHorizontalDragUpdate: (d) => pick(d.localPosition),
              child: AnimatedBuilder(
                animation: reveal,
                builder: (context, _) => CustomPaint(
                  size: Size(c.maxWidth, 140),
                  painter: _BarsPainter(
                    flows: f,
                    t: reveal.value,
                    picked: i,
                    grid: Theme.of(context).dividerColor,
                    axis: _axis(context),
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.flows, required this.t, required this.picked, required this.grid, required this.axis});

  final List<(int, int)> flows;
  final double t;
  final int picked;
  final Color grid;
  final TextStyle axis;

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 18.0;
    final n = flows.length;
    final h = size.height - labelH - 4;
    final slot = size.width / n;
    final maxV = flows.fold<int>(1, (m, f) => math.max(m, math.max(f.$1, f.$2))).toDouble();
    final barW = math.min(10.0, slot * .28);
    canvas.drawLine(Offset(0, h), Offset(size.width, h), Paint()
      ..color = grid
      ..strokeWidth = .5);

    for (var i = 0; i < n; i++) {
      // 달마다 조금씩 늦게 솟아오르게
      final start = i / n * .45;
      final k = Curves.easeOutBack.transform(((t - start) / .55).clamp(0.0, 1.0));
      final cx = slot * (i + .5);
      final dim = i == picked ? 1.0 : .45;
      for (final (j, v, c) in [(0, flows[i].$1, AppColors.green), (1, flows[i].$2, AppColors.orange)]) {
        final bh = math.max(v > 0 ? 3.0 : 0.0, h * v / maxV) * k;
        if (bh <= 0) continue;
        final left = j == 0 ? cx - barW - 1.5 : cx + 1.5;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(left, h - bh, barW, bh),
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          Paint()..color = c.withValues(alpha: dim),
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: i == picked ? axis.copyWith(fontWeight: FontWeight.w700, color: AppColors.blue) : axis,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, size.height - tp.height));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.t != t || o.picked != picked || o.flows != flows;
}

// ───────────────────────── 올해 어디에 썼나 (도넛) ─────────────────────────

class ExpenseDonutCard extends StatefulWidget {
  const ExpenseDonutCard({super.key, required this.year, required this.parts});

  final int year;

  /// (분류, 금액), 큰 순서.
  final List<(String, int)> parts;

  @override
  State<ExpenseDonutCard> createState() => _ExpenseDonutCardState();
}

class _ExpenseDonutCardState extends State<ExpenseDonutCard> with SingleTickerProviderStateMixin, _Reveal {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final total = widget.parts.fold<int>(0, (a, p) => a + p.$2);
    final donut = SizedBox.square(
      dimension: 132,
      child: AnimatedBuilder(
        animation: reveal,
        builder: (context, _) => CustomPaint(
          painter: _DonutPainter(
            parts: widget.parts,
            t: Curves.easeInOutCubic.transform(reveal.value),
            track: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('총 지출', style: tt.labelSmall!.copyWith(color: AppColors.gray)),
              FittedBox(child: CountUp(total, style: tt.titleSmall)),
            ]),
          ),
        ),
      ),
    );
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (k, (name, v)) in widget.parts.indexed)
          FadeSlideIn(
            index: k + 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: categoryColor(name), borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(name, style: tt.bodyMedium, maxLines: 1)),
                Text('${(v * 100 / math.max(total, 1)).round()}%',
                    style: tt.bodySmall!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
          ),
      ],
    );
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${widget.year}년 어디에 썼나', style: tt.labelMedium),
        const SizedBox(height: 14),
        if (total == 0)
          Text('아직 지출이 없어요', style: tt.bodyMedium)
        else
          Row(children: [donut, const SizedBox(width: 20), Expanded(child: legend)]),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.parts, required this.t, required this.track});

  final List<(String, int)> parts;
  final double t;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    final total = parts.fold<int>(0, (a, p) => a + p.$2);
    if (total == 0) return;
    const gap = 0.035;
    var a = -math.pi / 2;
    final end = a + math.pi * 2 * t;
    for (final (name, v) in parts) {
      final sweep = math.pi * 2 * v / total;
      final s = math.min(sweep - (parts.length > 1 ? gap : 0), end - a);
      if (s > 0) {
        canvas.drawArc(rect, a, s, false, Paint()
          ..color = categoryColor(name)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt);
      }
      a += sweep;
      if (a >= end) break;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.t != t || o.parts != parts;
}
