import 'package:flutter_test/flutter_test.dart';
import 'package:kit_party/cards/card_parser.dart';

void main() {
  final rx = DateTime(2026, 11, 21, 19, 0);

  CardCharge p(String s, {String? hint}) {
    final c = parseCardMessage(s, received: rx, issuerHint: hint);
    expect(c, isNotNull, reason: s);
    return c!;
  }

  void check(CardCharge c, {required String issuer, String? tail, required int amount, required String merchant}) {
    expect(c.issuer, issuer);
    expect(c.cardTail, tail);
    expect(c.amount, amount);
    expect(c.merchant, merchant);
    expect(c.time, DateTime(2026, 11, 21, 18, 30));
  }

  test('신한 한 줄', () {
    check(p('[Web발신]\n신한카드(1234)승인 김*겸 52,000원(일시불)11/21 18:30 고기굽는집 누적1,234,000원'),
        issuer: '신한카드', tail: '1234', amount: 52000, merchant: '고기굽는집');
  });

  test('KB 여러 줄', () {
    check(p('[Web발신]\nKB국민카드1234승인\n김*겸님\n52,000원 일시불\n11/21 18:30\n고기굽는집\n누적1,234,000원'),
        issuer: 'KB국민카드', tail: '1234', amount: 52000, merchant: '고기굽는집');
  });

  test('삼성', () {
    check(p('[Web발신]\n삼성카드 승인 1234\n52,000원 일시불\n11/21 18:30 고기굽는집\n누적1,234,000원'),
        issuer: '삼성카드', tail: '1234', amount: 52000, merchant: '고기굽는집');
  });

  test('현대 (번호 없음)', () {
    check(p('[Web발신]\n현대카드 M 승인\n김*겸\n52,000원 일시불\n11/21 18:30\n고기굽는집\n누적 1,234,000원'),
        issuer: '현대카드', tail: null, amount: 52000, merchant: '고기굽는집');
  });

  test('하나 (시각이 금액보다 앞)', () {
    check(p('[Web발신]\n하나(1234)김*겸님 11/21 18:30 일시불 52,000원 고기굽는집 누적1,234,000원'),
        issuer: '하나카드', tail: '1234', amount: 52000, merchant: '고기굽는집');
  });

  test('우리', () {
    check(p('[Web발신]\n우리(1234)승인\n김*겸님\n52,000원 일시불\n11/21 18:30\n고기굽는집\n누적1,234,000원'),
        issuer: '우리카드', tail: '1234', amount: 52000, merchant: '고기굽는집');
  });

  test('NH 가린 번호', () {
    check(p('[Web발신]\nNH카드1*2*승인\n김*겸\n52,000원 일시불\n11/21 18:30\n고기굽는집\n총누적1,234,000원'),
        issuer: 'NH농협카드', tail: '1*2*', amount: 52000, merchant: '고기굽는집');
  });

  test('롯데 한 줄', () {
    check(p('[Web발신]\n롯데카드 승인 김*겸님 52,000원 일시불 11/21 18:30 고기굽는집 누적 1,234,000원'),
        issuer: '롯데카드', tail: null, amount: 52000, merchant: '고기굽는집');
  });

  test('BC', () {
    check(p('[Web발신]\nBC카드(1234)승인 김*겸 52,000원 일시불 11/21 18:30 고기굽는집'),
        issuer: 'BC카드', tail: '1234', amount: 52000, merchant: '고기굽는집');
  });

  test('카카오뱅크 체크', () {
    check(p('[Web발신]\n카카오뱅크 체크카드(1234) 승인\n52,000원\n11/21 18:30\n고기굽는집'),
        issuer: '카카오뱅크', tail: '1234', amount: 52000, merchant: '고기굽는집');
  });

  test('할부와 취소', () {
    final c = p('[Web발신]\n신한카드(1234)승인취소 김*겸 230,000원(03개월)11/21 18:30 바다펜션');
    expect(c.isCancel, isTrue);
    expect(c.installment, 3);
    expect(c.amount, 230000);
  });

  test('앱 알림 (카드사 이름 없음, 날짜 없음)', () {
    final c = parseCardMessage('52,000원 결제\n고기굽는집 18:30', received: rx, issuerHint: '삼성카드', source: 'noti')!;
    expect(c.issuer, '삼성카드');
    expect(c.amount, 52000);
    expect(c.merchant, '고기굽는집');
    expect(c.time, DateTime(2026, 11, 21, 18, 30));
  });

  test('1월에 받은 12월 문자는 작년', () {
    final c = parseCardMessage('신한카드(1234)승인 김*겸 10,000원(일시불)12/31 23:10 편의점',
        received: DateTime(2027, 1, 1, 0, 5))!;
    expect(c.time.year, 2026);
  });

  test('카드 결제가 아닌 문자는 무시', () {
    expect(parseCardMessage('[국민은행] 입금 30,000원 김신겸 잔액 1,000,000원', received: rx), isNull);
    expect(parseCardMessage('신한카드 11월 결제예정금액 1,234,000원', received: rx), isNull);
    expect(parseCardMessage('오늘 저녁 7시 모임 잊지마세요', received: rx), isNull);
  });

  test('같은 결제 알아보기', () {
    final a = p('신한카드(1234)승인 김*겸 52,000원(일시불)11/21 18:30 고기굽는집');
    final b = parseCardMessage('52,000원 승인 고기굽는집 18:31', received: rx, issuerHint: '신한카드', source: 'noti')!;
    expect(a.sameAs(b), isTrue);
  });

  test('분류 짐작', () {
    const cats = ['정기모임', '번개', '식사', '숙박', '교통', '마트', '시설이용', '주차', '기타'];
    expect(guessCategory('바다펜션', cats), '숙박');
    expect(guessCategory('GS25 강남점', cats), '마트');
    expect(guessCategory('강남역공영주차장', cats), '주차');
    expect(guessCategory('SK에너지 서초', cats), '교통');
    expect(guessCategory('럭키볼링장', cats), '시설이용');
    expect(guessCategory('고기굽는집', cats), '식사');
  });
}
