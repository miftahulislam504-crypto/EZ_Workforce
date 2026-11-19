import 'package:flutter/material.dart';

/// Brand palette.
class Palette {
  const Palette._();

  static const Color brand = Color(0xFF4F46E5);
  static const Color brandDeep = Color(0xFF3730A3);
  static const Color brandSoft = Color(0xFFEEF0FF);
  static const Color accent = Color(0xFF0EA5A4);

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
}

/// Semantic colour tokens that Material's [ColorScheme] does not cover.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.pageBackground,
    required this.surfaceAlt,
    required this.border,
    required this.mutedText,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.brandSoft,
    required this.sidebar,
    required this.sidebarText,
    required this.sidebarMuted,
    required this.heroGradient,
    required this.shadow,
  });

  final Color pageBackground;
  final Color surfaceAlt;
  final Color border;
  final Color mutedText;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  final Color brandSoft;
  final Color sidebar;
  final Color sidebarText;
  final Color sidebarMuted;
  final Gradient heroGradient;
  final Color shadow;

  static const AppColors light = AppColors(
    pageBackground: Color(0xFFF5F6FB),
    surfaceAlt: Color(0xFFF1F3F9),
    border: Color(0xFFE5E8F2),
    mutedText: Color(0xFF667085),
    success: Palette.success,
    successSoft: Color(0xFFE8F6EE),
    warning: Palette.warning,
    warningSoft: Color(0xFFFEF3E2),
    danger: Palette.danger,
    dangerSoft: Color(0xFFFDECEC),
    info: Palette.info,
    infoSoft: Color(0xFFE8F0FE),
    brandSoft: Palette.brandSoft,
    sidebar: Color(0xFF0F1530),
    sidebarText: Color(0xFFE8EAF6),
    sidebarMuted: Color(0xFF8C93B8),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    ),
    shadow: Color(0x140F1530),
  );

  static const AppColors dark = AppColors(
    pageBackground: Color(0xFF0A0E1F),
    surfaceAlt: Color(0xFF181F3B),
    border: Color(0xFF263052),
    mutedText: Color(0xFF9AA3C7),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF12301F),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0xFF3A2A0B),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF3B1517),
    info: Color(0xFF60A5FA),
    infoSoft: Color(0xFF12274D),
    brandSoft: Color(0xFF202754),
    sidebar: Color(0xFF070A18),
    sidebarText: Color(0xFFE8EAF6),
    sidebarMuted: Color(0xFF7F87AE),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3730A3), Color(0xFF6D28D9)],
    ),
    shadow: Color(0x66000000),
  );

  @override
  AppColors copyWith({
    Color? pageBackground,
    Color? surfaceAlt,
    Color? border,
    Color? mutedText,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? brandSoft,
    Color? sidebar,
    Color? sidebarText,
    Color? sidebarMuted,
    Gradient? heroGradient,
    Color? shadow,
  }) {
    return AppColors(
      pageBackground: pageBackground ?? this.pageBackground,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      mutedText: mutedText ?? this.mutedText,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      brandSoft: brandSoft ?? this.brandSoft,
      sidebar: sidebar ?? this.sidebar,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarMuted: sidebarMuted ?? this.sidebarMuted,
      heroGradient: heroGradient ?? this.heroGradient,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
