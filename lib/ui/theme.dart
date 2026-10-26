import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 애플 느낌의 깔끔한 테마: 옅은 회색 바탕 + 흰 카드 + 파란 포인트 한 가지.
class AppColors {
  static const blue = Color(0xFF007AFF);
  static const blueDark = Color(0xFF0A84FF);
  static const green = Color(0xFF34C759);
  static const red = Color(0xFFFF3B30);
  static const orange = Color(0xFFFF9500);
  static const gray = Color(0xFF8E8E93);
}

class AppTheme {
  static const font = 'Pretendard';

  static ThemeData light() => _build(
        brightness: Brightness.light,
        bg: const Color(0xFFF2F2F7),
        surface: Colors.white,
        primary: AppColors.blue,
        label: Colors.black,
        secondary: const Color(0x993C3C43),
        separator: const Color(0x4A3C3C43),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        bg: Colors.black,
        surface: const Color(0xFF1C1C1E),
        primary: AppColors.blueDark,
        label: Colors.white,
        secondary: const Color(0x99EBEBF5),
        separator: const Color(0x99545458),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color primary,
    required Color label,
    required Color secondary,
    required Color separator,
  }) {
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
      primary: primary,
      surface: surface,
      onSurface: label,
      onSurfaceVariant: secondary,
      outlineVariant: separator,
      error: AppColors.red,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: font);
    TextStyle t(double size, FontWeight w, [Color? c]) =>
        TextStyle(fontFamily: font, fontSize: size, fontWeight: w, color: c ?? label, letterSpacing: -0.2);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: separator,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: base.textTheme.copyWith(
        displaySmall: t(34, FontWeight.w700),
        headlineMedium: t(28, FontWeight.w700),
        titleLarge: t(20, FontWeight.w600),
        titleMedium: t(17, FontWeight.w600),
        bodyLarge: t(17, FontWeight.w400),
        bodyMedium: t(15, FontWeight.w400),
        bodySmall: t(13, FontWeight.w400, secondary),
        labelLarge: t(15, FontWeight.w600),
        labelMedium: t(13, FontWeight.w500, secondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: t(17, FontWeight.w600),
        foregroundColor: primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => t(11, FontWeight.w500, s.contains(WidgetState.selected) ? primary : AppColors.gray),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 26, color: s.contains(WidgetState.selected) ? primary : AppColors.gray),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: bg,
        indicatorColor: primary.withValues(alpha: 0.12),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: const IconThemeData(color: AppColors.gray),
        selectedLabelTextStyle: t(12, FontWeight.w600, primary),
        unselectedLabelTextStyle: t(12, FontWeight.w500, AppColors.gray),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: t(17, FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: surface,
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: t(14, FontWeight.w500),
        showCheckmark: false,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
