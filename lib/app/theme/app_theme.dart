import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const purple10 = Color(0xFF09006B);
  static const purple30 = Color(0xFF312EBD);
  static const purple50 = Color(0xFF6768F2);
  static const purple70 = Color(0xFFA1A2FF);
  static const purple95 = Color(0xFFEFF0FF);

  static const green40 = Color(0xFF006D3B);
  static const green60 = Color(0xFF00A65D);
  static const green80 = Color(0xFF00E280);
  static const green95 = Color(0xFFC2FFD0);

  static const neon60 = Color(0xFF00A483);
  static const neon90 = Color(0xFF00FFCE);

  static const grey10 = Color(0xFF17171C);
  static const grey20 = Color(0xFF2E2E38);
  static const grey30 = Color(0xFF454554);
  static const grey50 = Color(0xFF73738C);
  static const grey70 = Color(0xFFA4A4B5);
  static const grey80 = Color(0xFFC7C7D1);
  static const grey90 = Color(0xFFE3E3E8);
  static const grey95 = Color(0xFFF1F1F3);
  static const grey97 = Color(0xFFF7F7F8);

  static const red40 = Color(0xFFBF002E);
  static const red60 = Color(0xFFFF344F);
  static const red95 = Color(0xFFFFE5E9);
  static const yellow30 = Color(0xFF996E00);
  static const yellow60 = Color(0xFFFFC633);
  static const blue40 = Color(0xFF027DCA);
}

@immutable
class SysThemeColors extends ThemeExtension<SysThemeColors> {
  const SysThemeColors({
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.auxiliaryText,
    required this.actionHover,
  });

  final Color bg1;
  final Color bg2;
  final Color bg3;
  final Color auxiliaryText;
  final Color actionHover;

  @override
  SysThemeColors copyWith({
    Color? bg1,
    Color? bg2,
    Color? bg3,
    Color? auxiliaryText,
    Color? actionHover,
  }) {
    return SysThemeColors(
      bg1: bg1 ?? this.bg1,
      bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3,
      auxiliaryText: auxiliaryText ?? this.auxiliaryText,
      actionHover: actionHover ?? this.actionHover,
    );
  }

  @override
  SysThemeColors lerp(covariant SysThemeColors? other, double t) {
    if (other == null) return this;
    return SysThemeColors(
      bg1: Color.lerp(bg1, other.bg1, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      bg3: Color.lerp(bg3, other.bg3, t)!,
      auxiliaryText: Color.lerp(auxiliaryText, other.auxiliaryText, t)!,
      actionHover: Color.lerp(actionHover, other.actionHover, t)!,
    );
  }
}

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.purple50,
      onPrimary: Colors.white,
      primaryContainer: AppColors.purple95,
      onPrimaryContainer: AppColors.purple10,
      secondary: AppColors.green80,
      onSecondary: AppColors.grey20,
      secondaryContainer: AppColors.green95,
      onSecondaryContainer: AppColors.grey20,
      tertiary: AppColors.neon90,
      onTertiary: AppColors.grey20,
      error: AppColors.red60,
      onError: Colors.white,
      errorContainer: AppColors.red95,
      onErrorContainer: AppColors.red40,
      surface: Colors.white,
      onSurface: AppColors.grey10,
      outline: AppColors.grey80,
      outlineVariant: AppColors.grey90,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.grey20,
      onInverseSurface: AppColors.grey97,
      inversePrimary: AppColors.purple70,
      surfaceTint: AppColors.purple50,
    );
    return _build(
      scheme,
      const SysThemeColors(
        bg1: AppColors.grey97,
        bg2: AppColors.grey95,
        bg3: AppColors.grey90,
        auxiliaryText: AppColors.grey50,
        actionHover: AppColors.purple95,
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.purple70,
      onPrimary: AppColors.purple10,
      primaryContainer: AppColors.purple30,
      onPrimaryContainer: AppColors.purple95,
      secondary: AppColors.green80,
      onSecondary: AppColors.grey20,
      secondaryContainer: AppColors.green40,
      onSecondaryContainer: AppColors.green95,
      tertiary: AppColors.neon90,
      onTertiary: AppColors.grey20,
      error: Color(0xFFFF99A7),
      onError: Color(0xFF680015),
      errorContainer: AppColors.red40,
      onErrorContainer: AppColors.red95,
      surface: AppColors.grey10,
      onSurface: AppColors.grey97,
      outline: AppColors.grey50,
      outlineVariant: AppColors.grey30,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.grey95,
      onInverseSurface: AppColors.grey20,
      inversePrimary: AppColors.purple30,
      surfaceTint: AppColors.purple70,
    );
    return _build(
      scheme,
      const SysThemeColors(
        bg1: AppColors.grey20,
        bg2: AppColors.grey30,
        bg3: AppColors.grey50,
        auxiliaryText: AppColors.grey70,
        actionHover: AppColors.purple30,
      ),
    );
  }

  static ThemeData _build(ColorScheme scheme, SysThemeColors sysColors) {
    final textTheme = GoogleFonts.poppinsTextTheme().apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: sysColors.bg1,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontSize: 48,
          fontWeight: FontWeight.w600,
        ),
        displayMedium: textTheme.displayMedium?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      extensions: [sysColors],
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: const CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(40, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
    );
    return base;
  }
}
