import 'package:flutter_test/flutter_test.dart';
import 'package:kit_party/data/seed_2026.dart';
import 'package:kit_party/models/ledger_math.dart';
import 'package:kit_party/models/models.dart';

void main() {
  final txns = seedTxns();
  final members = seedMembers();

  test('시트에서 옮긴 잔고가 시트와 같다 (7,675,165원)', () {
    expect(LedgerMath.balance(seedSettings, txns), 7675165);
  });

  test('시트 요약 탭의 합계와 같다', () {
    expect(LedgerMath.sum(txns, type: TxnType.income), 2599864);
    expect(LedgerMath.sum(txns, type: TxnType.expense), 2483222);
    expect(LedgerMath.sum(txns, category: '회비'), 2160000);
    expect(LedgerMath.sum(txns, category: '정기모임'), 1038022);
    expect(LedgerMath.sum(txns, category: '번개'), 846200);
    expect(LedgerMath.sum(txns, category: '생일선물'), 500000);
    expect(LedgerMath.sum(txns, category: '이자'), 160 + 65440);
  });

  test('10월 기준 미납: 기록 없는 6명 중 면제 2명 빼고 4명', () {
    final d = LedgerMath.dues(members: members, txns: txns, settings: seedSettings, asOf: DateTime(2026, 10, 26));
    final unpaid = d.where((x) => x.isUnpaid).map((x) => x.member.name).toSet();
    expect(unpaid, {'권오정', '신지만', '최진영', '김창희'});
    final exempt = d.where((x) => x.exempt).map((x) => x.member.name).toSet();
    expect(exempt, {'손승현', '이준섭'});
  });

  test('1년치를 미리 낸 사람은 미납이 아니고 12월분까지 채워진다', () {
    final d = LedgerMath.dues(members: members, txns: txns, settings: seedSettings, asOf: DateTime(2026, 12, 31));
    final lee = d.firstWhere((x) => x.member.name == '이창식');
    expect(lee.paid, 360000);
    expect(lee.isUnpaid, false);
    expect(lee.monthsCovered, 12);
  });

  test('Firestore 저장 형식으로 바꿨다 되돌려도 같다', () {
    final t = txns.first;
    final back = Txn.fromMap(t.id, t.toMap());
    expect(back.amount, t.amount);
    expect(back.date, t.date);
    expect(back.memberId, t.memberId);
    expect(back.type, t.type);
  });
}
