import 'dart:async';

import '../models/models.dart';
import 'repository.dart';
import 'seed_2026.dart';

/// Firebase 연결 전 체험용. 시트 데이터를 메모리에 올려두고 바로 반영해요.
class DemoRepository implements LedgerRepository {
  DemoRepository() {
    final ms = seedMembers();
    // 체험 모드에서는 첫 번째 회원을 총무로 둡니다.
    ms[0] = ms[0].copyWith(role: Role.treasurer);
    _members.value = ms;
    _txns.value = seedTxns();
    _settings.value = seedSettings;
    _messages.value = [
      Message(
        id: 'welcome',
        authorId: ms[0].id,
        authorName: ms[0].name,
        text: '회비장부 앱에 오신 걸 환영합니다! 궁금한 건 여기 남겨주세요.',
        createdAt: DateTime(2026, 10, 25, 9),
        pinned: true,
      ),
    ];
  }

  final _members = _Box<List<Member>>();
  final _txns = _Box<List<Txn>>();
  final _messages = _Box<List<Message>>();
  final _settings = _Box<LedgerSettings>();
  var _seq = 0;

  @override
  bool get isDemo => true;

  @override
  Stream<List<Member>> members() => _members.stream;
  @override
  Stream<List<Txn>> txns() => _txns.stream;
  @override
  Stream<List<Message>> messages() => _messages.stream;
  @override
  Stream<LedgerSettings> settings() => _settings.stream;

  @override
  Future<void> saveTxn(Txn t) async {
    final id = t.id.isEmpty ? 'demo_${_seq++}' : t.id;
    final saved = Txn(
      id: id,
      date: t.date,
      type: t.type,
      category: t.category,
      item: t.item,
      amount: t.amount,
      memberId: t.memberId,
      memo: t.memo,
      receiptUrl: t.receiptUrl,
    );
    _txns.value = [..._txns.value.where((x) => x.id != id), saved];
  }

  @override
  Future<void> deleteTxn(String id) async => _txns.value = _txns.value.where((x) => x.id != id).toList();

  @override
  Future<void> setExempt(String memberId, int year, bool exempt) async {
    _members.value = [
      for (final m in _members.value)
        if (m.id == memberId)
          m.copyWith(
              exemptYears: exempt
                  ? {...m.exemptYears, year}.toList()
                  : m.exemptYears.where((y) => y != year).toList())
        else
          m,
    ];
  }

  @override
  Future<void> transferTreasurer(String fromMemberId, String toMemberId) async {
    _members.value = [
      for (final m in _members.value)
        if (m.id == fromMemberId)
          m.copyWith(role: Role.member)
        else if (m.id == toMemberId)
          m.copyWith(role: Role.treasurer)
        else
          m,
    ];
  }

  @override
  Future<void> setPinned(String messageId, bool pinned) async {
    _messages.value = [
      for (final m in _messages.value)
        if (m.id == messageId)
          Message(
              id: m.id,
              authorId: m.authorId,
              authorName: m.authorName,
              text: m.text,
              createdAt: m.createdAt,
              pinned: pinned)
        else
          m,
    ];
  }

  @override
  Future<void> postMessage(Message m) async {
    _messages.value = [
      ..._messages.value,
      Message(
          id: 'msg_${_seq++}',
          authorId: m.authorId,
          authorName: m.authorName,
          text: m.text,
          createdAt: m.createdAt),
    ];
  }

  @override
  Future<void> deleteMessage(String id) async => _messages.value = _messages.value.where((m) => m.id != id).toList();
}

/// 최신 값을 기억하고, 새로 듣는 쪽에도 바로 보내주는 작은 상자.
class _Box<T> {
  late T _value;
  final _ctrl = StreamController<T>.broadcast();

  T get value => _value;
  set value(T v) {
    _value = v;
    _ctrl.add(v);
  }

  Stream<T> get stream async* {
    yield _value;
    yield* _ctrl.stream;
  }
}
