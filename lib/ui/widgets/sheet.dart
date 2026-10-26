import 'package:flutter/material.dart';

import '../../state/app_state.dart';

/// 아래에서 올라오는 창. 앱 상태를 넘겨주고, 폰 하단 버튼(뒤로가기 줄)에
/// 가리지 않게 그 높이만큼 띄워요. 내용이 길면 스크롤돼요.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder, {bool scrollable = true}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: AppScope.carry(
        context,
        (c) => SafeArea(
          top: false,
          child: scrollable ? SingleChildScrollView(child: builder(c)) : builder(c),
        ),
      ),
    );
