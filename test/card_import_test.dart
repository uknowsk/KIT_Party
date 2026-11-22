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

    await tester.tap(find.text('최근 30일'));
    await tester.pumpAndSettle();
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
}
