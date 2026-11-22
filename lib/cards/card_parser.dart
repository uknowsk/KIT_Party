/// 카드 승인 문자·알림 글자를 읽어서 "어느 카드로, 언제, 어디서, 얼마" 를 뽑아요.
///
/// 플러터 없이 순수 다트만 써요. 총무노트 앱에도 그대로 복사해 쓸 수 있어요.
library;

/// 카드 결제 한 건.
class CardCharge {
  /// 카드사 이름 (예: 신한카드). 못 찾으면 '카드'.
  final String issuer;

  /// 카드 끝 번호 (예: 1234). 문자에 없으면 null.
  final String? cardTail;

  final int amount;

  /// 가맹점 (예: 스타벅스 강남점). 못 찾으면 빈 글자.
  final String merchant;

  final DateTime time;

  /// 승인 취소 문자인지.
  final bool isCancel;

  /// 할부 개월 (일시불이면 0).
  final int installment;

  /// 문자/알림 원문.
  final String raw;

  /// 'sms' 또는 'noti'.
  final String source;

  const CardCharge({
    required this.issuer,
    this.cardTail,
    required this.amount,
    required this.merchant,
    required this.time,
    this.isCancel = false,
    this.installment = 0,
    required this.raw,
    this.source = 'sms',
  });

  /// 카드 고르기에 쓰는 이름: "신한카드 1234" 또는 "신한카드".
  String get cardLabel => cardTail == null ? issuer : '$issuer $cardTail';

  /// 같은 결제인지 가려낼 열쇠 (문자와 알림이 둘 다 와도 한 번만).
  String get key => '${time.millisecondsSinceEpoch ~/ 60000}|$amount|${cardTail ?? issuer}';

  bool sameAs(CardCharge o) =>
      amount == o.amount &&
      isCancel == o.isCancel &&
      (cardTail == null || o.cardTail == null || cardTail == o.cardTail) &&
      time.difference(o.time).inMinutes.abs() <= 3;
}

/// 카드사 이름표. 앞쪽이 먼저 맞춰봐요.
final _issuers = <(RegExp, String)>[
  (RegExp(r'KB\s*국민|국민카드|KB카드|KB\s*\d'), 'KB국민카드'),
  (RegExp(r'신한'), '신한카드'),
  (RegExp(r'삼성'), '삼성카드'),
  (RegExp(r'현대카드|현대\s*\(|현대\d'), '현대카드'),
  (RegExp(r'롯데'), '롯데카드'),
  (RegExp(r'하나'), '하나카드'),
  (RegExp(r'우리'), '우리카드'),
  (RegExp(r'NH|농협'), 'NH농협카드'),
  (RegExp(r'BC|비씨'), 'BC카드'),
  (RegExp(r'씨티|citi', caseSensitive: false), '씨티카드'),
  (RegExp(r'카카오\s*뱅크|카카오뱅크'), '카카오뱅크'),
  (RegExp(r'카카오페이'), '카카오페이'),
  (RegExp(r'토스'), '토스뱅크'),
  (RegExp(r'케이뱅크|K뱅크'), '케이뱅크'),
  (RegExp(r'IBK|기업'), 'IBK기업'),
  (RegExp(r'SC|제일'), 'SC제일'),
  (RegExp(r'수협'), '수협카드'),
  (RegExp(r'광주'), '광주카드'),
  (RegExp(r'전북'), '전북카드'),
  (RegExp(r'경남'), '경남카드'),
  (RegExp(r'부산|BNK'), 'BNK부산'),
  (RegExp(r'대구|DGB|iM'), 'iM뱅크'),
  (RegExp(r'우체국'), '우체국'),
  (RegExp(r'새마을|MG'), '새마을금고'),
  (RegExp(r'신협'), '신협'),
];

/// 알림을 보낸 앱 → 카드사 (알림 글자에 카드사 이름이 없을 때 써요).
const packageIssuers = <String, String>{
  'com.shcard.smartpay': '신한카드',
  'com.shinhancard.smartshinhan': '신한카드',
  'com.kbcard.cxh.appcard': 'KB국민카드',
  'com.kbcard.kbkookmincard': 'KB국민카드',
  'kvp.jjy.MispAndroid320': 'KB국민카드',
  'kr.co.samsungcard.mpocket': '삼성카드',
  'com.hyundaicard.appcard': '현대카드',
  'com.lcacApp': '롯데카드',
  'com.lottemembers.android': '롯데카드',
  'com.hanaskcard.paycla': '하나카드',
  'com.hanaskcard.rocomo.potal': '하나카드',
  'com.wooricard.smartapp': '우리카드',
  'com.wooricard.wpay': '우리카드',
  'nh.smart.nhallonepay': 'NH농협카드',
  'nh.smart.card': 'NH농협카드',
  'com.bccard.android.mobile': 'BC카드',
  'com.bccard.paybooc': 'BC카드',
  'com.kakaobank.channel': '카카오뱅크',
  'viva.republica.toss': '토스뱅크',
  'com.kbankwith.smartbank': '케이뱅크',
  'com.citibank.cardapp': '씨티카드',
};

final _amountRe = RegExp(r'(\d{1,3}(?:,\d{3})+|\d+)\s*원');
final _mdTimeRe = RegExp(r'(\d{1,2})/(\d{1,2})\s*(\d{1,2}):(\d{2})');
final _mdRe = RegExp(r'(\d{1,2})월\s*(\d{1,2})일(?:\s*(\d{1,2}):(\d{2}))?');
final _timeOnlyRe = RegExp(r'(?<!\d)(\d{1,2}):(\d{2})(?!\d)');
final _tailRe = <RegExp>[
  RegExp(r'\((\d{4})\)'),
  RegExp(r'\(([\d*]{4})\)'),
  RegExp(r'카드\s*\(?(\d{4})\)?'),
  RegExp(r'승인\s*\(?(\d{4})\)?(?!\d|,|원)'),
  RegExp(r'([\d*]{4})\s*승인'),
  RegExp(r'(\d\*\d\*)'),
];
final _installRe = RegExp(r'(\d{1,2})\s*개월');
final _noiseRe = RegExp(
  r'(누적|잔액|총누적|사용가능|이용가능|한도)\s*:?\s*-?[\d,]+\s*원?|\[Web발신\]|\[국외발신\]|\(광고\)',
);

/// 카드 결제 문자처럼 보이나? (승인/결제 + 금액). 입출금 문자는 빼요.
bool looksLikeCardCharge(String text) {
  if (!_amountRe.hasMatch(text)) return false;
  if (!RegExp(r'승인|결제|사용|취소|일시불|할부').hasMatch(text)) return false;
  // 통장 입출금 알림 (예: "입금 30,000원 잔액 ...") 은 빼요.
  if (RegExp(r'입금').hasMatch(text) && !RegExp(r'카드|체크').hasMatch(text)) return false;
  if (RegExp(r'결제\s*예정|청구|명세서|자동납부\s*안내|이용대금').hasMatch(text)) return false;
  return true;
}

/// 문자 한 통을 읽어요. 카드 결제가 아니면 null.
///
/// [received]: 문자가 온 시각. 글자에 연도가 없어서 이걸로 연도를 정해요.
/// [issuerHint]: 알림을 보낸 앱으로 짐작한 카드사.
CardCharge? parseCardMessage(
  String text, {
  required DateTime received,
  String? issuerHint,
  String source = 'sms',
}) {
  final raw = text.trim();
  if (raw.isEmpty || !looksLikeCardCharge(raw)) return null;

  // 1) 카드사
  String? issuer;
  for (final (re, name) in _issuers) {
    if (re.hasMatch(raw)) {
      issuer = name;
      break;
    }
  }
  issuer ??= issuerHint;
  if (issuer == null && !RegExp(r'카드|체크').hasMatch(raw)) return null;
  issuer ??= '카드';

  // 2) 금액 (누적·잔액 금액은 지우고 찾아요)
  final clean = raw.replaceAll(_noiseRe, ' ');
  final am = _amountRe.firstMatch(clean);
  if (am == null) return null;
  final amount = int.tryParse(am.group(1)!.replaceAll(',', '')) ?? 0;
  if (amount <= 0) return null;

  // 3) 카드 끝번호
  String? tail;
  for (final re in _tailRe) {
    final m = re.firstMatch(clean);
    if (m != null) {
      final g = m.group(1)!;
      // "18:30" 의 시각이나 금액 일부를 번호로 잘못 잡지 않게
      if (g.contains('*') || !clean.contains('$g원')) {
        tail = g;
        break;
      }
    }
  }

  // 4) 날짜·시각
  DateTime time = received;
  Match? dm = _mdTimeRe.firstMatch(clean);
  int? month, day, hour, minute;
  if (dm != null) {
    month = int.parse(dm.group(1)!);
    day = int.parse(dm.group(2)!);
    hour = int.parse(dm.group(3)!);
    minute = int.parse(dm.group(4)!);
  } else {
    dm = _mdRe.firstMatch(clean);
    if (dm != null) {
      month = int.parse(dm.group(1)!);
      day = int.parse(dm.group(2)!);
      if (dm.group(3) != null) {
        hour = int.parse(dm.group(3)!);
        minute = int.parse(dm.group(4)!);
      }
    } else {
      dm = _timeOnlyRe.firstMatch(clean);
      if (dm != null) {
        hour = int.parse(dm.group(1)!);
        minute = int.parse(dm.group(2)!);
      }
    }
  }
  if (month != null && day != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
    var year = received.year;
    // 1월에 받은 12월 결제 문자
    if (month > received.month + 1) year -= 1;
    time = DateTime(year, month, day, hour ?? 0, minute ?? 0);
  } else if (hour != null && hour < 24 && minute! < 60) {
    time = DateTime(received.year, received.month, received.day, hour, minute);
  }

  // 5) 할부·취소
  final isCancel = RegExp(r'취소').hasMatch(clean);
  final inst = _installRe.firstMatch(clean);
  final installment = inst == null ? 0 : int.parse(inst.group(1)!);

  // 6) 가맹점
  final merchant = _merchant(clean, dm);

  return CardCharge(
    issuer: issuer,
    cardTail: tail,
    amount: amount,
    merchant: merchant,
    time: time,
    isCancel: isCancel,
    installment: installment,
    raw: raw,
    source: source,
  );
}

/// 남는 글자 중 가맹점 이름을 골라요.
String _merchant(String clean, Match? dateMatch) {
  String strip(String s) => s
      .replaceAll(_amountRe, ' ')
      .replaceAll(RegExp(r'일시불|할부|\d{1,2}\s*개월|승인취소|승인|취소|결제|사용'), ' ')
      .replaceAll(_mdTimeRe, ' ')
      .replaceAll(_mdRe, ' ')
      .replaceAll(_timeOnlyRe, ' ')
      .replaceAll(RegExp(r'[|·•]'), ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .trim();

  bool junk(String s) {
    if (s.isEmpty) return true;
    if (RegExp(r'카드|체크|뱅크|은행').hasMatch(s) && s.length <= 14) return true; // 카드사 줄
    if (RegExp(r'^\S*\*\S*(님)?$').hasMatch(s)) return true; // 홍*동님
    if (RegExp(r'님$').hasMatch(s) && s.length <= 6) return true;
    if (RegExp(r'^[\d*()\-\s]+$').hasMatch(s)) return true; // 번호만
    if (RegExp(r'^(KB|NH|BC|IBK|SC)$').hasMatch(s)) return true;
    return false;
  }

  // 날짜 뒤쪽부터 보고, 없으면 앞쪽을 봐요.
  final after = dateMatch == null ? '' : clean.substring(dateMatch.end);
  final before = dateMatch == null ? clean : clean.substring(0, dateMatch.start);
  for (final part in [after, before]) {
    final lines = part.split(RegExp(r'[\n\r]+'));
    final ordered = identical(part, before) ? lines.reversed : lines;
    for (final line in ordered) {
      var s = strip(line);
      // 한 줄짜리 문자: "홍*동님 12,000원 스타벅스" → 이름 조각 지우기
      s = s.replaceAll(RegExp(r'\S*\*\S*님?'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      // 카드사 이름 조각 지우기
      s = s
          .replaceAll(RegExp(r'^(\S*카드|\S*체크카드|\S*뱅크)\s*(\(\S*\))?\s*'), '')
          .replaceAll(RegExp(r'^\(?[\d*]{4}\)?\s*'), '')
          .trim();
      if (!junk(s)) return s.length > 30 ? s.substring(0, 30) : s;
    }
  }
  return '';
}

/// 가맹점 이름으로 지출 분류를 짐작해요. [categories]에 있는 것만 돌려줘요.
String guessCategory(String merchant, List<String> categories, {String fallback = '식사'}) {
  const rules = <(String, String)>[
    ('주차', r'주차|파킹|parking'),
    ('숙박', r'호텔|모텔|펜션|리조트|숙박|게스트하우스|여기어때|야놀자|에어비앤비|airbnb|글램핑|콘도'),
    ('교통', r'주유|에너지|오일|SK에너지|GS칼텍스|S-OIL|현대오일|택시|카카오T|고속|KTX|코레일|SRT|버스|하이패스|도로공사|톨게이트|티머니|렌터카|쏘카|항공|에어'),
    ('마트', r'마트|이마트|홈플러스|코스트코|하나로|편의점|GS25|CU|씨유|세븐일레븐|이마트24|미니스톱|슈퍼|다이소|쿠팡|마켓'),
    ('시설이용', r'노래|코인|볼링|당구|골프|스크린|PC방|피씨방|찜질|사우나|수영|체육|캠핑|입장|매표|박물관|공원|워터|스파|키즈'),
  ];
  for (final (cat, pattern) in rules) {
    if (categories.contains(cat) && RegExp(pattern, caseSensitive: false).hasMatch(merchant)) return cat;
  }
  return categories.contains(fallback) ? fallback : categories.first;
}
