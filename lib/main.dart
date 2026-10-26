import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/demo_repository.dart';
import 'data/seed_2026.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';
import 'ui/shell.dart';
import 'ui/sign_in.dart';
import 'ui/splash.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options != null) {
    await Firebase.initializeApp(options: options);
  }
  runApp(KitPartyApp(useFirebase: options != null));
}

class KitPartyApp extends StatelessWidget {
  const KitPartyApp({super.key, required this.useFirebase, this.demoState});

  final bool useFirebase;

  /// 테스트에서 미리 만든 상태를 넣을 때.
  final AppState? demoState;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '회비장부',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // 폰 글씨 크기 설정은 따르되, 화면이 깨지지 않게 1.3배까지만.
        builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
        home: SplashGate(child: useFirebase ? const AuthGate() : _DemoRoot(state: demoState)),
      );
}

class _DemoRoot extends StatefulWidget {
  const _DemoRoot({this.state});

  final AppState? state;

  @override
  State<_DemoRoot> createState() => _DemoRootState();
}

class _DemoRootState extends State<_DemoRoot> {
  late final AppState _state = widget.state ?? AppState(DemoRepository(), myMemberId: memberIdOf(seedTreasurer));

  @override
  Widget build(BuildContext context) => AppScope(
        state: _state,
        child: ListenableBuilder(
          listenable: _state,
          builder: (_, _) => _state.ready ? const AppShell() : const SizedBox.shrink(),
        ),
      );
}
