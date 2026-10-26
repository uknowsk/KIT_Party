import 'package:flutter/material.dart';

import 'pages/dues_page.dart';
import 'pages/home_page.dart';
import 'pages/ledger_page.dart';
import 'pages/messages_page.dart';
import 'pages/settings_page.dart';

/// 세로 화면: 아래 탭 5개 / 가로·큰 화면: 왼쪽 메뉴.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, '홈'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, '장부'),
    (Icons.people_outline_rounded, Icons.people_rounded, '회비'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, '메시지'),
    (Icons.settings_outlined, Icons.settings_rounded, '설정'),
  ];

  Widget _page(int i) => switch (i) {
        0 => HomePage(onOpenDues: () => setState(() => _index = 2)),
        1 => const LedgerPage(),
        2 => const DuesPage(),
        3 => const MessagesPage(),
        _ => SettingsPage(onSignOut: widget.onSignOut),
      };

  @override
  Widget build(BuildContext context) {
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(a), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(_index), child: _page(_index)),
    );

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 600;
      if (wide) {
        return Scaffold(
          body: SafeArea(
            right: false,
            child: Row(children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.6,
                destinations: [
                  for (final t in _tabs)
                    NavigationRailDestination(icon: Icon(t.$1), selectedIcon: Icon(t.$2), label: Text(t.$3)),
                ],
              ),
              VerticalDivider(width: 0.5, thickness: 0.5, color: Theme.of(context).dividerColor),
              Expanded(child: body),
            ]),
          ),
        );
      }
      return Scaffold(
        body: body,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final t in _tabs)
                NavigationDestination(icon: Icon(t.$1), selectedIcon: Icon(t.$2), label: t.$3),
            ],
          ),
        ),
      );
    });
  }
}
