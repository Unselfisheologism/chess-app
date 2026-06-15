import 'package:flutter/material.dart';

import 'brand.dart';
import 'spacing.dart';
import 'typography.dart';

/// App-wide theme. Light + dark variants share the same brand palette
/// and type scale; only the color scheme and scaffold background change.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: BrandColors.deepInk,
        onPrimary: BrandColors.cream,
        secondary: BrandColors.gold,
        onSecondary: BrandColors.deepInk,
        surface: BrandColors.cream,
        onSurface: BrandColors.deepInk,
        error: BrandColors.error,
        onError: BrandColors.cream,
      ),
      scaffoldBackgroundColor: BrandColors.cream,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTypography.display,
        headlineLarge: AppTypography.h1,
        headlineMedium: AppTypography.h2,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.caption,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.cream,
        foregroundColor: BrandColors.deepInk,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        margin: const EdgeInsets.all(AppSpacing.m),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.m),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: BrandColors.gold,
        onPrimary: BrandColors.deepInk,
        secondary: BrandColors.cream,
        onSecondary: BrandColors.deepInk,
        surface: BrandColors.deepInk,
        onSurface: BrandColors.cream,
        error: BrandColors.error,
        onError: BrandColors.cream,
      ),
      scaffoldBackgroundColor: BrandColors.deepInk,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTypography.display.copyWith(color: BrandColors.cream),
        headlineLarge: AppTypography.h1.copyWith(color: BrandColors.cream),
        headlineMedium: AppTypography.h2.copyWith(color: BrandColors.cream),
        bodyLarge: AppTypography.body.copyWith(color: BrandColors.cream),
        bodyMedium: AppTypography.caption.copyWith(color: BrandColors.cream),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.deepInk,
        foregroundColor: BrandColors.cream,
        elevation: 0,
      ),
    );
  }
}
