import '../models/models.dart';

/// 앱이 데이터를 읽고 쓰는 창구.
/// 실제 서비스는 Firestore, 연결 전에는 체험용 데모 데이터를 써요.
abstract class LedgerRepository {
  bool get isDemo;

  Stream<List<Member>> members();
  Stream<List<Txn>> txns();
  Stream<List<Message>> messages();
  Stream<LedgerSettings> settings();

  // 총무만 (서버 보안 규칙에서도 막혀 있어요)
  Future<void> saveTxn(Txn t);
  Future<void> deleteTxn(String id);
  Future<void> setExempt(String memberId, int year, bool exempt);

  /// 회장 정하기 (총무만).
  Future<void> setPresident(String memberId);

  /// 생일 넣기·지우기 (총무만). [mmdd]가 null이면 지워요.
  Future<void> setBirthday(String memberId, String? mmdd);
  Future<void> transferTreasurer(String fromMemberId, String toMemberId);
  Future<void> setPinned(String messageId, bool pinned);

  // 누구나
  Future<void> postMessage(Message m);
  Future<void> deleteMessage(String id);
}
