import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kit_party/main.dart';
import 'package:kit_party/ui/pages/ledger_page.dart';
import 'package:kit_party/ui/pages/txn_editor.dart';
import 'package:kit_party/ui/widgets/charts.dart';
import 'package:kit_party/ui/widgets/common.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const KitPartyApp(useFirebase: false));
    await tester.pumpAndSettle();
  }

  testWidgets('처음 열면 학교 로고와 "99 제어계측 동기"가 보이고, 곧 앱으로 넘어간다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const KitPartyApp(useFirebase: false));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('99 제어계측 동기'), findsOneWidget);
    expect(find.bySemanticsLabel('국립금오공과대학교'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('99 제어계측 동기'), findsNothing);
    expect(find.text('지금 잔고'), findsOneWidget);
  });

  testWidgets('세로 화면: 하단 탭 5개가 보이고 탭을 옮겨 다닐 수 있다', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('지금 잔고'), findsOneWidget);
    for (final tab in ['장부', '회비', '메시지', '설정']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('가로 화면: 왼쪽 메뉴로 바뀐다', (tester) async {
    await pumpAt(tester, const Size(844, 390));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('작은 폰에서도 넘치지 않는다', (tester) async {
    await pumpAt(tester, const Size(320, 640));
    for (final tab in ['장부', '회비', '메시지', '설정', '홈']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('폰 글씨를 크게 해도 넘치지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpAt(tester, const Size(360, 740));
    for (final tab in ['장부', '회비', '메시지', '설정', '홈']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('기록 추가·이자 입력·기록 상세 창이 뜬다', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    for (final b in ['기록 추가', '이자 입력']) {
      await tester.tap(find.text(b));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TxnEditor), findsOneWidget, reason: b);
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.byType(TxnEditor), findsNothing);
    }
    // 장부 탭: + 버튼과 기록 누르기
    await tester.tap(find.text('장부').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TxnEditor), findsOneWidget);
    await tester.tapAt(const Offset(195, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TxnTile).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TxnDetail), findsOneWidget);
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TxnEditor), findsOneWidget);
    Navigator.of(tester.element(find.byType(TxnEditor))).pop();
    await tester.pumpAndSettle();
    // 회비 탭: 회원 카드 누르기
    await tester.tap(find.text('회비').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('이창식'), 200);
    await tester.tap(find.text('이창식'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('홈에 그래프 3개가 그려진다', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.byType(BalanceTrendCard), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(ExpenseDonutCard), 300);
    expect(find.byType(MonthlyFlowCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('아래 창 버튼이 폰 하단 뒤로가기 줄에 가리지 않는다', (tester) async {
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    await pumpAt(tester, const Size(390, 844));
    await tester.tap(find.text('장부').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TxnTile).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final fix = tester.getRect(find.ancestor(of: find.text('수정'), matching: find.byType(FilledButton)));
    expect(fix.bottom, lessThanOrEqualTo(844 - 48));
  });
}
