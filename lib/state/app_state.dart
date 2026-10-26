import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/repository.dart';
import '../models/models.dart';

/// 화면 전체가 함께 쓰는 상태: 데이터 + 지금 로그인한 회원.
class AppState extends ChangeNotifier {
  AppState(this.repo, {this._myMemberId}) {
    _subs = [
      repo.members().listen((v) => _set(() => members = v)),
      repo.txns().listen((v) => _set(() => txns = [...v]..sort((a, b) => b.date.compareTo(a.date)))),
      repo.messages().listen((v) => _set(() => messages = [...v]..sort((a, b) => a.createdAt.compareTo(b.createdAt)))),
      repo.settings().listen((v) => _set(() => settings = v)),
    ];
  }

  final LedgerRepository repo;
  late final List<StreamSubscription> _subs;

  List<Member> members = const [];
  List<Txn> txns = const [];
  List<Message> messages = const [];
  LedgerSettings? settings;

  String? _myMemberId;

  bool get ready => settings != null && members.isNotEmpty;

  Member? get me {
    for (final m in members) {
      if (m.id == _myMemberId) return m;
    }
    return null;
  }

  bool get isTreasurer => me?.isTreasurer ?? false;

  Member? memberById(String? id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Member? get treasurer {
    for (final m in members) {
      if (m.isTreasurer) return m;
    }
    return null;
  }

  /// 체험 모드에서 "누구로 볼지" 바꾸기.
  void actAs(String memberId) => _set(() => _myMemberId = memberId);

  void _set(VoidCallback f) {
    f();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
