import 'package:flutter/material.dart';

/// 앱을 처음 열 때 잠깐 보여주는 화면: 금오공대 로고 + "99 제어계측 동기".
/// 끝나갈 무렵 실제 앱(child)을 그리기 시작하고, 로고 화면이 부드럽게 사라진다.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..addListener(_tick)
    ..forward();

  bool _showApp = false;
  bool _done = false;

  void _tick() {
    if (!_showApp && _c.value >= 0.78) setState(() => _showApp = true);
    if (!_done && _c.isCompleted) setState(() => _done = true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _part(double a, double b, [Curve curve = Curves.easeOutCubic]) => CurvedAnimation(
    parent: _c,
    curve: Interval(a, b, curve: curve),
  );

  late final _logoIn = _part(0.0, 0.32);
  late final _textIn = _part(0.22, 0.52);
  late final _out = _part(0.80, 1.0, Curves.easeInOut);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final logoWidth = [size.width * 0.74, 340.0, size.height * 1.4].reduce((a, b) => a < b ? a : b);

    return Stack(
      children: [
        if (_showApp) Positioned.fill(child: widget.child),
        if (!_done)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _showApp,
              child: AnimatedBuilder(
                animation: _out,
                builder: (context, child) => Opacity(opacity: 1 - _out.value, child: child),
                child: Material(
                  color: dark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
                  child: SafeArea(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FadeTransition(
                            opacity: _logoIn,
                            child: ScaleTransition(
                              scale: Tween(begin: 0.94, end: 1.0).animate(_logoIn),
                              child: Image.asset(
                                dark ? 'assets/brand/kit_logo_dark.png' : 'assets/brand/kit_logo.png',
                                width: logoWidth,
                                semanticLabel: '국립금오공과대학교',
                              ),
                            ),
                          ),
                          SizedBox(height: logoWidth * 0.12),
                          FadeTransition(
                            opacity: _textIn,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(_textIn),
                              child: Text(
                                '99 제어계측 동기',
                                style: Theme.of(context).textTheme.headlineSmall!
                                    .copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
