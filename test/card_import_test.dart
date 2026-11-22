import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kit_party/cards/card_parser.dart';
import 'package:kit_party/data/demo_repository.dart';
import 'package:kit_party/data/seed_2026.dart';
import 'package:kit_party/state/app_state.dart';
import 'package:kit_party/ui/pages/card_import_page.dart';
import 'package:kit_party/ui/theme.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  testWidgets('카드 결제를 골라 장부에 올린다 (분류 짐작 포함)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final rx = now.subtract(const Duration(days: 2));
    String md(DateTime d) => '${d.month}/${d.day} 18:30';
    final charges = [
      parseCardMessage('신한카드(1234)승인 김*겸 52,000원(일시불)${md(rx)} 고기굽는집', received: rx)!,
      parseCardMessage('신한카드(1234)승인 김*겸 120,000원(일시불)${md(rx)} 바다펜션', received: rx)!,
      parseCardMessage('KB국민카드5678승인\n김*겸님\n9,900원 일시불\n${md(rx)}\nGS25 강남점', received: rx)!,
    ];

    final state = AppState(DemoRepository(), myMemberId: memberIdOf(seedTreasurer));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: AppScope(state: state, child: CardImportPage(preload: charges)),
    ));
    await tester.pumpAndSettle();
    final before = state.txns.length;

    // 날짜를 안 고르면 아무것도 안 보여요
    expect(find.text('고기굽는집'), findsNothing);
    await tester.tap(find.byKey(const Key('cardPickDates')));
    await tester.pumpAndSettle();
    if (rx.month != now.month) {
      await tester.tap(find.byTooltip('이전 달'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(ValueKey('day-${rx.month}-${rx.day}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('datesDone')));
    await tester.pumpAndSettle();
    expect(find.text('${rx.month}/${rx.day} (${const ['월', '화', '수', '목', '금', '토', '일'][rx.weekday - 1]})'), findsOneWidget);
    expect(find.text('고기굽는집'), findsOneWidget);
    expect(find.text('숙박'), findsOneWidget);
    expect(find.text('마트'), findsOneWidget);

    // 신한 1234 카드만 보기
    await tester.tap(find.widgetWithText(FilterChip, '신한카드 1234'));
    await tester.pumpAndSettle();
    expect(find.text('GS25 강남점'), findsNothing);

    await tester.tap(find.text('전체 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cardSaveSelected')));
    await tester.pumpAndSettle();

    expect(state.txns.length, before + 2);
    expect(state.txns.any((t) => t.item == '바다펜션' && t.category == '숙박' && t.amount == 120000), isTrue);
    // 올린 건 목록에서 빠져요
    expect(find.textContaining('저장하지 못했어요'), findsNothing);
    expect(find.text('고기굽는집'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('권한이 꺼져 있을 때: 켜기 줄이 깨지지 않고 버튼이 눌린다', (tester) async {
    for (final size in const [Size(390, 844), Size(320, 640), Size(844, 390)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final state = AppState(DemoRepository(), myMemberId: memberIdOf(seedTreasurer));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: AppScope(state: state, child: const CardImportPage(preload: [], preloadGranted: false)),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.text('카드 결제 문자 읽기'), findsOneWidget);
      // 제목이 한 줄로 보일 만큼 넓은지 (세로로 한 글자씩 깨지지 않게)
      expect(tester.getSize(find.text('카드 결제 문자 읽기')).width, greaterThan(100), reason: '$size');
      final btn = find.widgetWithText(FilledButton, '켜기').first;
      expect(tester.getSize(btn).width, lessThan(size.width / 2), reason: '$size');
      await tester.tap(btn);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
    }
    tester.view.reset();
  });
}
