import 'dart:async';

import '../models/models.dart';
import 'repository.dart';
import 'seed_2026.dart';

/// Firebase 연결 전 체험용. 시트 데이터를 메모리에 올려두고 바로 반영해요.
class DemoRepository implements LedgerRepository {
  DemoRepository() {
    final ms = seedMembers();
    final treasurer = ms.firstWhere((m) => m.isTreasurer);
    _members.value = ms;
    _txns.value = seedTxns();
    _settings.value = seedSettings;
    _messages.value = [
      Message(
        id: 'welcome',
        authorId: treasurer.id,
        authorName: treasurer.name,
        text: '회비장부 앱에 오신 걸 환영합니다! 궁금한 건 여기 남겨주세요.',
        createdAt: DateTime(2026, 10, 25, 9),
        pinned: true,
      ),
    ];
    final ids = [for (final m in ms) m.id];
    _meetings.value = [
      Meeting(
        id: 'mt_1',
        date: DateTime(2026, 4, 18),
        kind: MeetingKind.regular,
        region: '부산',
        place: '해운대',
        attendeeIds: ids.take(10).toList(),
      ),
      Meeting(
        id: 'mt_2',
        date: DateTime(2026, 6, 5),
        kind: MeetingKind.flash,
        place: '대전 성심당 근처',
        attendeeIds: ids.skip(2).take(5).toList(),
      ),
      Meeting(
        id: 'mt_3',
        date: DateTime(2026, 9, 12),
        kind: MeetingKind.regular,
        region: '서울·경기',
        place: '수원',
        attendeeIds: ids.skip(1).take(9).toList(),
      ),
    ];
    _notices.value = [
      Notice(
        id: 'nt_1',
        authorId: treasurer.id,
        authorName: treasurer.name,
        title: '12월 정기모임 날짜 정해요',
        body: '이번엔 충청 차례예요. 되는 날을 모두 골라 주세요!',
        createdAt: DateTime(2026, 10, 28, 20),
        poll: const Poll(options: ['12월 6일 (토)', '12월 13일 (토)', '12월 20일 (토)'], multi: true),
        votes: {ids[1]: [0, 1], ids[2]: [1], ids[3]: [1, 2]},
      ),
    ];
  }

  final _meetings = _Box<List<Meeting>>();
  final _notices = _Box<List<Notice>>();

  @override
  Stream<List<Meeting>> meetings() => _meetings.stream;
  @override
  Stream<List<Notice>> notices() => _notices.stream;

  @override
  Future<void> saveMeeting(Meeting m) async {
    final id = m.id.isEmpty ? 'mt_d${_seq++}' : m.id;
    _meetings.value = [..._meetings.value.where((x) => x.id != id), m.withId(id)];
  }

  @override
  Future<void> deleteMeeting(String id) async => _meetings.value = _meetings.value.where((x) => x.id != id).toList();

  @override
  Future<void> setRotation(List<String> order) async => _settings.value = _settings.value.copyWith(rotation: order);

  @override
  Future<void> postNotice(Notice n) async =>
      _notices.value = [..._notices.value, n.copyWith(id: 'nt_d${_seq++}', votes: const {}, closed: false)];

  @override
  Future<void> deleteNotice(String id) async => _notices.value = _notices.value.where((x) => x.id != id).toList();

  @override
  Future<void> setNoticeClosed(String id, bool closed) async =>
      _notices.value = [for (final n in _notices.value) n.id == id ? n.copyWith(closed: closed) : n];

  @override
  Future<void> vote(String noticeId, String memberId, List<int> choices) async => _notices.value = [
        for (final n in _notices.value)
          n.id == noticeId ? n.copyWith(votes: {...n.votes, memberId: choices}) : n,
      ];

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
  Future<void> setBirthday(String memberId, String? mmdd) async {
    _members.value = [for (final m in _members.value) m.id == memberId ? m.withBirthday(mmdd) : m];
  }

  @override
  Future<void> setPresident(String memberId) async {
    _settings.value = _settings.value.copyWith(presidentId: memberId);
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
