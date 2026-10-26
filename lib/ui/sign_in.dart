import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/firestore_repository.dart';
import '../data/seed_2026.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'shell.dart';
import 'theme.dart';

/// Firebase가 연결된 뒤의 흐름: 구글 로그인 → (처음이면) 이름 고르고 가입 신청 → 총무 승인 → 앱.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const _Splash();
          final user = snap.data;
          if (user == null) return const _SignInPage();
          return _MemberGate(user: user);
        },
      );
}

class _MemberGate extends StatefulWidget {
  const _MemberGate({required this.user});

  final User user;

  @override
  State<_MemberGate> createState() => _MemberGateState();
}

class _MemberGateState extends State<_MemberGate> {
  final _repo = FirestoreRepository();
  AppState? _state;

  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<String?>(
        stream: _repo.linkedMemberIdStream(widget.user.uid),
        builder: (context, snap) {
          if (!snap.hasData && snap.connectionState == ConnectionState.waiting) return const _Splash();
          final memberId = snap.data;
          if (memberId == null) {
            return StreamBuilder<bool>(
              stream: _repo.setupDone(),
              builder: (context, setup) {
                if (!setup.hasData) return const _Splash();
                return setup.data!
                    ? _JoinPage(repo: _repo, user: widget.user)
                    : _SetupPage(repo: _repo, user: widget.user);
              },
            );
          }
          _state ??= AppState(_repo, myMemberId: memberId);
          return AppScope(
            state: _state!,
            child: ListenableBuilder(
              listenable: _state!,
              builder: (_, _) => _state!.ready ? AppShell(onSignOut: AuthService.signOut) : const _Splash(),
            ),
          );
        },
      );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CupertinoActivityIndicator(radius: 14)));
}

class _SignInPage extends StatefulWidget {
  const _SignInPage();

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/brand/kit_drop.png', width: 88, height: 88),
                const SizedBox(height: 20),
                Text('회비장부', style: tt.displaySmall),
                const SizedBox(height: 8),
                Text('우리 모임 돈, 투명하게', style: tt.bodyMedium!.copyWith(color: AppColors.gray)),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await AuthService.signInWithGoogle();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('구글 계정으로 시작하기'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinPage extends StatelessWidget {
  const _JoinPage({required this.repo, required this.user});

  final FirestoreRepository repo;
  final User user;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 이름 고르기'),
        actions: [TextButton(onPressed: AuthService.signOut, child: const Text('로그아웃'))],
      ),
      body: StreamBuilder<List<Member>>(
        stream: repo.members(),
        builder: (context, snap) {
          final members = (snap.data ?? const <Member>[]).where((m) => m.uid == null).toList();
          return StreamBuilder<String?>(
            stream: repo.myJoinRequest(user.uid),
            builder: (context, req) {
              if (req.data != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('가입 신청을 보냈어요.\n총무가 승인하면 바로 열려요.',
                        textAlign: TextAlign.center, style: tt.titleMedium),
                  ),
                );
              }
              return ListView(padding: const EdgeInsets.all(16), children: [
                Text('명단에서 내 이름을 눌러 가입 신청하세요.', style: tt.bodyMedium),
                const SizedBox(height: 12),
                for (final m in members)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      tileColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      title: Text(m.name),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => repo.requestJoin(uid: user.uid, memberId: m.id, email: user.email),
                    ),
                  ),
              ]);
            },
          );
        },
      ),
    );
  }
}

/// 앱을 맨 처음 켠 사람에게만 나오는 화면: 내 이름을 고르면 명단과 시트 데이터를 올려요.
class _SetupPage extends StatefulWidget {
  const _SetupPage({required this.repo, required this.user});

  final FirestoreRepository repo;
  final User user;

  @override
  State<_SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<_SetupPage> {
  String _memberId = memberIdOf(seedTreasurer);
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.repo.bootstrap(uid: widget.user.uid, memberId: _memberId, email: widget.user.email);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('설정 실패: $e')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('처음 설정'),
        actions: [TextButton(onPressed: AuthService.signOut, child: const Text('로그아웃'))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('아직 장부가 비어 있어요.\n내 이름을 고르면 회원 명단과 구글 시트 기록(2026년 1~10월)을 올리고, '
            '내가 우선 총무 권한을 받아요. 나중에 설정에서 총무를 넘길 수 있어요.',
            style: tt.bodyMedium),
        const SizedBox(height: 16),
        for (final n in seedMemberNames)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              tileColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text(n == seedTreasurer ? '$n (현재 총무)' : n),
              trailing: _memberId == memberIdOf(n)
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.blue)
                  : null,
              onTap: () => setState(() => _memberId = memberIdOf(n)),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _busy ? null : _run, child: Text(_busy ? '올리는 중…' : '이 이름으로 시작하기')),
      ]),
    );
  }
}
