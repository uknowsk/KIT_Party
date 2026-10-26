import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kit_party/main.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const KitPartyApp(useFirebase: false));
    await tester.pumpAndSettle();
  }

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
}
