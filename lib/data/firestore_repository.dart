import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';
import 'repository.dart';
import 'seed_2026.dart';

/// Firestore 구조
/// - members/{memberId}      회원 명단 (이름, 역할, 연결된 uid, 면제 연도)
/// - users/{uid}             로그인 계정 ↔ 회원 연결. 보안 규칙이 역할을 여기서 읽어요.
/// - joinRequests/{uid}      가입 신청 (총무가 승인)
/// - transactions/{id}       입출금 기록
/// - messages/{id}           메시지
/// - config/settings         시작 잔고, 월 회비, 최신 앱 버전
class FirestoreRepository implements LedgerRepository {
  FirestoreRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _members => _db.collection('members');
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _txns => _db.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _messages => _db.collection('messages');
  DocumentReference<Map<String, dynamic>> get _settings => _db.collection('config').doc('settings');

  @override
  bool get isDemo => false;

  @override
  Stream<List<Member>> members() =>
      _members.snapshots().map((s) => [for (final d in s.docs) Member.fromMap(d.id, d.data())]);

  @override
  Stream<List<Txn>> txns() =>
      _txns.snapshots().map((s) => [for (final d in s.docs) Txn.fromMap(d.id, d.data())]);

  @override
  Stream<List<Message>> messages() => _messages
      .orderBy('createdAt')
      .limitToLast(300)
      .snapshots()
      .map((s) => [for (final d in s.docs) Message.fromMap(d.id, d.data())]);

  @override
  Stream<LedgerSettings> settings() =>
      _settings.snapshots().map((d) => LedgerSettings.fromMap(d.data() ?? const {}));

  @override
  Future<void> saveTxn(Txn t) {
    final data = {
      ...t.toMap(),
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return t.id.isEmpty ? _txns.add(data) : _txns.doc(t.id).set(data);
  }

  @override
  Future<void> deleteTxn(String id) => _txns.doc(id).delete();

  @override
  Future<void> setExempt(String memberId, int year, bool exempt) => _members.doc(memberId).update({
        'exemptYears': exempt ? FieldValue.arrayUnion([year]) : FieldValue.arrayRemove([year]),
      });

  @override
  Future<void> setBirthday(String memberId, String? mmdd) =>
      _members.doc(memberId).update({'birthday': mmdd ?? FieldValue.delete()});

  @override
  Future<void> setPresident(String memberId) =>
      _settings.set({'presidentId': memberId}, SetOptions(merge: true));

  @override
  Future<void> transferTreasurer(String fromMemberId, String toMemberId) async {
    final from = Member.fromMap(fromMemberId, (await _members.doc(fromMemberId).get()).data() ?? {});
    final to = Member.fromMap(toMemberId, (await _members.doc(toMemberId).get()).data() ?? {});
    if (to.uid == null) {
      throw StateError('${to.name}님은 아직 앱에 가입하지 않았어요.');
    }
    // 한 번에 묶어서 저장해요. 중간에 끊겨도 총무가 0명이나 2명이 되지 않아요.
    final b = _db.batch()
      ..update(_members.doc(toMemberId), {'role': 'treasurer'})
      ..set(_users.doc(to.uid), {'role': 'treasurer'}, SetOptions(merge: true))
      ..update(_members.doc(fromMemberId), {'role': 'member'});
    if (from.uid != null) b.set(_users.doc(from.uid), {'role': 'member'}, SetOptions(merge: true));
    await b.commit();
  }

  @override
  Future<void> setPinned(String messageId, bool pinned) => _messages.doc(messageId).update({'pinned': pinned});

  @override
  Future<void> postMessage(Message m) => _messages.add({
        ...m.toMap(),
        'authorUid': FirebaseAuth.instance.currentUser?.uid,
      });

  @override
  Future<void> deleteMessage(String id) => _messages.doc(id).delete();

  // ---- 처음 설정 ----

  DocumentReference<Map<String, dynamic>> get _setup => _db.collection('meta').doc('setup');

  /// 처음 설정(명단·시트 데이터 업로드)이 끝났는지.
  Stream<bool> setupDone() => _setup.snapshots().map((d) => d.exists);

  /// 앱을 처음 켠 사람이 한 번만 실행: 명단, 설정, 시트 기록을 올리고
  /// 그 사람을 고른 이름과 연결해 총무 권한을 줘요. (보안 규칙이 한 번만 허용)
  Future<void> bootstrap({required String uid, required String memberId, String? email}) async {
    final b = _db.batch();
    for (final m in seedMembers()) {
      final role = m.id == memberId ? Role.treasurer : Role.member;
      b.set(_members.doc(m.id), m.copyWith(role: role, uid: m.id == memberId ? uid : null).toMap());
    }
    b.set(_users.doc(uid), {'memberId': memberId, 'role': 'treasurer', 'email': email});
    b.set(_settings, seedSettings.toMap());
    for (final t in seedTxns()) {
      b.set(_txns.doc(t.id), {...t.toMap(), 'updatedBy': uid, 'updatedAt': FieldValue.serverTimestamp()});
    }
    b.set(_setup, {'by': uid, 'at': FieldValue.serverTimestamp()});
    await b.commit();
  }

  // ---- 가입 ----

  Stream<List<JoinRequest>> joinRequests() => _db.collection('joinRequests').snapshots().map((s) => [
        for (final d in s.docs)
          JoinRequest(uid: d.id, memberId: d.data()['memberId'] as String? ?? '', email: d.data()['email'] as String?),
      ]);

  /// 로그인한 계정이 연결된 회원 id. 아직 승인 전이면 null.
  Stream<String?> linkedMemberIdStream(String uid) =>
      _users.doc(uid).snapshots().map((d) => d.data()?['memberId'] as String?);

  /// 내가 보낸 가입 신청 (보낸 회원 id).
  Stream<String?> myJoinRequest(String uid) =>
      _db.collection('joinRequests').doc(uid).snapshots().map((d) => d.data()?['memberId'] as String?);

  Future<void> requestJoin({required String uid, required String memberId, String? email}) =>
      _db.collection('joinRequests').doc(uid).set({
        'memberId': memberId,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// 총무가 가입 신청을 승인.
  Future<void> approveJoin(String uid, String memberId) => (_db.batch()
        ..set(_users.doc(uid), {'memberId': memberId, 'role': 'member'})
        ..update(_members.doc(memberId), {'uid': uid})
        ..delete(_db.collection('joinRequests').doc(uid)))
      .commit();
}

class JoinRequest {
  final String uid;
  final String memberId;
  final String? email;

  const JoinRequest({required this.uid, required this.memberId, this.email});
}
