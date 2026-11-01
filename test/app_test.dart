import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kit_party/data/demo_repository.dart';
import 'package:kit_party/data/seed_2026.dart';
import 'package:kit_party/main.dart';
import 'package:kit_party/models/models.dart';
import 'package:kit_party/state/app_state.dart';
import 'package:kit_party/models/meeting_math.dart';
import 'package:kit_party/ui/pages/ledger_page.dart';
import 'package:kit_party/ui/pages/meetings_page.dart';
import 'package:kit_party/ui/pages/notices_page.dart';
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

  testWidgets('세로 화면: 하단 탭 6개가 보이고 탭을 옮겨 다닐 수 있다', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('지금 잔고'), findsOneWidget);
    for (final tab in ['장부', '회비', '모임', '소식', '설정']) {
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
    for (final tab in ['장부', '회비', '모임', '소식', '설정', '홈']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('폰 글씨를 크게 해도 넘치지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpAt(tester, const Size(360, 740));
    for (final tab in ['장부', '회비', '모임', '소식', '설정', '홈']) {
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

  Future<AppState> pumpAs(WidgetTester tester, String name) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(DemoRepository(), myMemberId: memberIdOf(name));
    await tester.pumpWidget(KitPartyApp(useFirebase: false, demoState: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정').last);
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> toggleExempt(WidgetTester tester, String name, String action) async {
    await tester.scrollUntilVisible(find.text(name).last, 200);
    await Scrollable.ensureVisible(tester.element(find.text(name).last), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('회장(차광훈)은 배지만 있고 면제 메뉴는 없다', (tester) async {
    final s = await pumpAs(tester, '차광훈');
    expect(s.isPresident, isTrue);
    expect(s.canManageExempt, isFalse);
    expect(find.text('회장'), findsWidgets);
    await tester.scrollUntilVisible(find.text('손승현').last, 200);
    await Scrollable.ensureVisible(tester.element(find.text('손승현').last), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('손승현').last);
    await tester.pumpAndSettle();
    expect(find.text('면제 풀기'), findsNothing);
  });

  testWidgets('총무는 회원 목록에서 면제를 걸고 풀 수 있다', (tester) async {
    final t = await pumpAs(tester, seedTreasurer);
    expect(t.canManageExempt, isTrue);
    final year = DateTime.now().year;
    bool exempt() => t.memberById(memberIdOf('이창식'))!.isExempt(year);
    await toggleExempt(tester, '이창식', '회비 면제하기');
    expect(exempt(), isTrue);
    await toggleExempt(tester, '이창식', '회비 면제 풀기');
    expect(exempt(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('일반 회원은 면제 메뉴가 없다', (tester) async {
    final m = await pumpAs(tester, '이창식');
    expect(m.canManageExempt, isFalse);
    await tester.scrollUntilVisible(find.text('김기범').last, 200);
    await Scrollable.ensureVisible(tester.element(find.text('김기범').last), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('김기범').last);
    await tester.pumpAndSettle();
    expect(find.text('회비 면제하기'), findsNothing);
  });

  testWidgets('총무가 회원 목록에서 생일을 넣고 지운다', (tester) async {
    final t = await pumpAs(tester, seedTreasurer);
    await toggleExempt(tester, '김기범', '생일 넣기');
    expect(find.text('김기범 생일'), findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(t.memberById(memberIdOf('김기범'))!.birthday, '01-01');
    expect(find.text('🎂 1월 1일'), findsOneWidget);
    await toggleExempt(tester, '김기범', '생일 지우기');
    expect(t.memberById(memberIdOf('김기범'))!.birthday, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('이번 달 생일자가 홈에 보인다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(DemoRepository(), myMemberId: memberIdOf('이창식'));
    final now = DateTime.now();
    await tester.pumpWidget(KitPartyApp(useFirebase: false, demoState: state));
    await tester.pumpAndSettle();
    expect(find.text('${now.month}월 생일'), findsNothing);
    await state.repo.setBirthday(memberIdOf('손승현'), Member.birthdayKey(now.month, 12));
    // 새로 생긴 카드가 살짝 늦게 떠오르는 효과(타이머)까지 흘려보내요.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('${now.month}월 생일'), findsOneWidget);
    expect(find.text('손승현 12일'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('장부에서 월간·연간 수입/지출을 본다', (tester) async {
    for (final size in [const Size(390, 844), const Size(320, 640), const Size(844, 390)]) {
      await tester.pumpWidget(const SizedBox());
      await pumpAt(tester, size);
      await tester.tap(find.text('장부').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('월간'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      expect(find.text('${now.year}년 ${now.month}월'), findsOneWidget);
      await tester.tap(find.byTooltip('이전'));
      await tester.pumpAndSettle();
      final prev = DateTime(now.year, now.month - 1);
      expect(find.text('${prev.year}년 ${prev.month}월'), findsOneWidget);
      expect(find.text('지출 항목별'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size 월간');
      await tester.tap(find.text('연간'));
      await tester.pumpAndSettle();
      expect(find.text('${now.year}년'), findsOneWidget);
      expect(find.byType(MonthlyFlowCard), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('ym1')), 200);
      await Scrollable.ensureVisible(tester.element(find.byKey(const ValueKey('ym1'))), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ym1')));
      await tester.pumpAndSettle();
      expect(find.text('${now.year}년 1월'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size 연간');
      await tester.pump(const Duration(seconds: 1));
    }
  });

  test('새 지출 항목이 있다', () {
    for (final c in ['숙박', '교통', '마트', '식사', '시설이용', '주차']) {
      expect(Categories.expense, contains(c));
    }
  });

  Future<AppState> openTab(WidgetTester tester, String name, String tab, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(DemoRepository(), myMemberId: memberIdOf(name));
    await tester.pumpWidget(KitPartyApp(useFirebase: false, demoState: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tab).last);
    await tester.pumpAndSettle();
    return state;
  }

  test('장소 로테이션: 마지막 정기모임 다음 지역, 기록 없으면 첫 지역', () {
    const order = Regions.all;
    expect(MeetingMath.nextRegion(order, const []), '서울·경기');
    final ms = [
      Meeting(id: 'a', date: DateTime(2026, 3), kind: MeetingKind.regular, region: '경상'),
      Meeting(id: 'b', date: DateTime(2026, 6), kind: MeetingKind.regular, region: '부산'),
      Meeting(id: 'c', date: DateTime(2026, 7), kind: MeetingKind.flash, region: '충청'),
    ];
    expect(MeetingMath.nextRegion(order, ms), '서울·경기', reason: '부산 다음은 처음으로, 번개는 안 셈');
    expect(MeetingMath.nextRegion(['부산', '경상', '충청', '서울·경기'], ms), '경상');
  });

  test('참석률: 모임 종류·연도별로 센다', () {
    final mem = [for (final n in ['가', '나']) Member(id: n, name: n)];
    final ms = [
      Meeting(id: '1', date: DateTime(2026, 1), kind: MeetingKind.regular, attendeeIds: const ['가', '나']),
      Meeting(id: '2', date: DateTime(2026, 2), kind: MeetingKind.flash, attendeeIds: const ['가']),
      Meeting(id: '3', date: DateTime(2025, 2), kind: MeetingKind.regular, attendeeIds: const ['나']),
    ];
    final all = MeetingMath.attendance(mem, ms);
    expect(all.first.member.name, '가');
    expect((all.first.attended, all.first.total), (2, 3));
    final y = MeetingMath.attendance(mem, ms, year: 2026, kind: MeetingKind.regular);
    expect([for (final a in y) a.percent], [100, 100]);
  });

  test('공지·투표는 저장 형식으로 바꿨다 되돌려도 같다', () {
    final n = Notice(
      id: 'x',
      authorId: 'm',
      authorName: '총무',
      title: '날짜',
      createdAt: DateTime(2026, 11, 1),
      poll: Poll(options: const ['A', 'B'], multi: true, deadline: DateTime(2026, 11, 5)),
      votes: const {'p': [0, 1], 'q': [1], 'r': []},
    );
    final back = Notice.fromMap('x', n.toMap());
    expect(back.counts, [1, 2]);
    expect(back.voters, 2);
    expect(back.poll!.multi, isTrue);
    expect(back.isOpen(DateTime(2026, 11, 4)), isTrue);
    expect(back.isOpen(DateTime(2026, 11, 6)), isFalse);
    expect(back.copyWith(closed: true).isOpen(DateTime(2026, 11, 2)), isFalse);
    final m = Meeting(id: 'm', date: DateTime(2026, 5, 2), kind: MeetingKind.flash, place: '대전', attendeeIds: const ['a']);
    final mb = Meeting.fromMap('m', m.toMap());
    expect((mb.kind, mb.place, mb.region), (MeetingKind.flash, '대전', null));
    expect(mb.attendeeIds, ['a']);
    final st = LedgerSettings.fromMap(const {'rotation': ['부산', '경상']});
    expect(st.rotation, ['부산', '경상']);
    expect(LedgerSettings.fromMap(const {}).rotation, Regions.all);
  });

  testWidgets('모임 탭: 다음 차례 지역이 보이고, 총무가 참석자와 함께 모임을 기록한다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '모임');
    // 데모: 마지막 정기모임이 서울·경기 → 다음은 충청
    expect(find.text('다음은 충청 차례', findRichText: true), findsOneWidget);
    await tester.tap(find.byTooltip('모임 기록하기'));
    await tester.pumpAndSettle();
    expect(find.byType(MeetingEditor), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '장소 (예: 대전 유성 ○○식당)'), '청주');
    await tester.tap(find.text('모두 넣기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilterChip, '이창식'));
    await tester.tap(find.widgetWithText(FilterChip, '이창식'));
    await tester.pumpAndSettle();
    expect(find.text('참석자 ${s.members.length - 1}명'), findsOneWidget);
    await tester.ensureVisible(find.text('저장'));
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final saved = s.meetings.first;
    expect((saved.region, saved.place, saved.attendeeIds.length), ('충청', '청주', s.members.length - 1));
    expect(saved.attendeeIds, isNot(contains(memberIdOf('이창식'))));
    expect(find.text('다음은 경상 차례', findRichText: true), findsOneWidget);
    // 참석률 보기
    await tester.tap(find.text('참석률'));
    await tester.pumpAndSettle();
    expect(find.text('모임 4번'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('총무가 장소 순서를 바꾼다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '모임');
    await tester.tap(find.text('순서 바꾸기'));
    await tester.pumpAndSettle();
    expect(find.text('장소 순서 바꾸기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await s.repo.setRotation(const ['부산', '경상', '충청', '서울·경기']);
    await tester.pumpAndSettle();
    expect(s.settings!.rotation.first, '부산');
  });

  testWidgets('일반 회원은 모임을 기록할 수 없고 보기만 한다', (tester) async {
    await openTab(tester, '이창식', '모임');
    expect(find.byTooltip('모임 기록하기'), findsNothing);
    expect(find.text('순서 바꾸기'), findsNothing);
    await tester.tap(find.textContaining('부산').last);
    await tester.pumpAndSettle();
    expect(find.text('수정'), findsNothing);
  });

  testWidgets('회원이 투표하고, 단일 투표는 하나만 골라진다', (tester) async {
    final s = await openTab(tester, '이창식', '소식');
    expect(find.text('12월 정기모임 날짜 정해요'), findsOneWidget);
    expect(find.byTooltip('새 공지'), findsNothing);
    final me = memberIdOf('이창식');
    await tester.tap(find.text('12월 6일 (토)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12월 20일 (토)'));
    await tester.pumpAndSettle();
    expect(s.notices.first.choicesOf(me), [0, 2], reason: '여러 개 고르기');
    // 단일 투표 하나 올려서 확인
    await s.repo.postNotice(Notice(
      id: '',
      authorId: 't',
      authorName: '총무',
      title: '장소 하나만',
      createdAt: DateTime.now(),
      poll: const Poll(options: ['청주', '대전']),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('청주'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대전'));
    await tester.pumpAndSettle();
    expect(s.notices.first.choicesOf(me), [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('총무가 날짜 투표를 올리고 마감한다', (tester) async {
    final s = await openTab(tester, seedTreasurer, '소식');
    await tester.tap(find.byTooltip('새 공지'));
    await tester.pumpAndSettle();
    expect(find.byType(NoticeEditor), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '제목 (예: 12월 정기모임 날짜)'), '송년회 장소');
    await tester.tap(find.text('투표 붙이기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '항목 1 (날짜나 장소)'), '대전');
    await tester.enterText(find.widgetWithText(TextField, '항목 2 (날짜나 장소)'), '청주');
    await tester.ensureVisible(find.text('항목 추가'));
    await tester.tap(find.text('항목 추가'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '항목 3 (날짜나 장소)'), findsOneWidget);
    await tester.ensureVisible(find.text('올리기'));
    await tester.tap(find.text('올리기'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final n = s.notices.first;
    expect((n.title, n.poll!.multi), ('송년회 장소', false));
    expect(n.poll!.options, ['대전', '청주']);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('투표 마감하기'));
    await tester.pumpAndSettle();
    expect(s.notices.first.closed, isTrue);
    expect(find.text('마감'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('홈에 진행 중 투표와 다음 모임 지역 카드가 보인다', (tester) async {
    await openTab(tester, '이창식', '홈');
    expect(find.text('진행 중인 투표 1개'), findsOneWidget);
    expect(find.text('다음 정기모임은 충청 차례'), findsOneWidget);
    await tester.tap(find.byKey(const Key('homePolls')));
    await tester.pumpAndSettle();
    expect(find.byType(NoticesView), findsOneWidget);
  });

  testWidgets('작은 폰·큰 글씨에서 모임·소식 화면이 넘치지 않는다', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openTab(tester, seedTreasurer, '모임', size: const Size(320, 640));
    await tester.tap(find.text('참석률'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('모임 기록하기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byType(MeetingEditor))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('소식').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('새 공지'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('투표 붙이기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('회장(차광훈)도 모임 기록과 공지를 쓸 수 있다', (tester) async {
    final s = await openTab(tester, '차광훈', '모임');
    expect(s.canManageEvents, isTrue);
    expect(find.byTooltip('모임 기록하기'), findsOneWidget);
    expect(find.text('순서 바꾸기'), findsNothing, reason: '장소 순서는 총무만');
    await tester.tap(find.text('소식').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('새 공지'), findsOneWidget);
  });
}
