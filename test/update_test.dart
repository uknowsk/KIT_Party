import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kit_party/update/release.dart';
import 'package:kit_party/update/update_prompt.dart';

void main() {
  test('버전 비교: 숫자 크기로 비교하고 v·빌드번호는 무시', () {
    expect(ReleaseInfo.compare('v1.0.10', '1.0.9'), greaterThan(0));
    expect(ReleaseInfo.compare('1.0.8', '1.0.8+9'), 0);
    expect(ReleaseInfo.compare('1.0.7', 'v1.1'), lessThan(0));
    expect(ReleaseInfo.compare('2.0.0', '1.9.9'), greaterThan(0));
  });

  test('GitHub 릴리즈 노트에서 바뀐 내용만 뽑는다', () {
    const body = "## What's Changed\n"
        '* 모임 탭(장소 로테이션·참석률) by @uknowsk in https://github.com/uknowsk/KIT_Party/pull/10\n'
        '* 업데이트 알림 추가 by @uknowsk in https://github.com/uknowsk/KIT_Party/pull/11\n\n'
        '## New Contributors\n'
        '* @someone made their first contribution in https://github.com/x/y/pull/1\n\n'
        '**Full Changelog**: https://github.com/uknowsk/KIT_Party/compare/v1.0.7...v1.0.8';
    expect(ReleaseInfo.parseNotes(body), ['모임 탭(장소 로테이션·참석률)', '업데이트 알림 추가']);
  });

  test('릴리즈 응답에서 APK 주소를 찾는다', () {
    final r = ReleaseInfo.fromGitHub({
      'tag_name': 'v1.0.8',
      'body': '* 새 기능',
      'assets': [
        {'name': 'kit-party.apk', 'browser_download_url': 'https://example.com/kit-party.apk'},
      ],
    })!;
    expect(r.version, '1.0.8');
    expect(r.apkUrl, 'https://example.com/kit-party.apk');
    expect(r.notes, ['새 기능']);
    expect(ReleaseInfo.fromGitHub({'tag_name': 'v1.0.8', 'assets': []}), isNull);
  });

  testWidgets('업데이트 창: 버전·바뀐 내용을 보여주고, 누르면 받아서 설치 화면을 연다', (tester) async {
    const rel = ReleaseInfo(version: '1.0.8', notes: ['업데이트 알림 추가'], apkUrl: 'x');
    File? installed;
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    showUpdateDialog(ctx, rel,
        current: '1.0.7',
        download: (r, onProgress) async {
          onProgress(1);
          return File('kit-party.apk');
        },
        install: (f) async => installed = f);
    await tester.pumpAndSettle();
    expect(find.text('새 버전이 나왔어요 🎉'), findsOneWidget);
    expect(find.text('지금 v1.0.7 → 새 버전 v1.0.8'), findsOneWidget);
    expect(find.text('업데이트 알림 추가'), findsOneWidget);

    await tester.tap(find.text('지금 업데이트'));
    await tester.pumpAndSettle();
    expect(installed?.path, 'kit-party.apk');
    expect(find.textContaining('설치 화면이 열렸어요'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.byType(UpdateDialog), findsNothing);
  });
}
