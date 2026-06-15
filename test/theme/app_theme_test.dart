import 'package:chess_do_it/theme/app_theme.dart';
import 'package:chess_do_it/theme/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme.light()', () {
    final theme = AppTheme.light();

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('is light brightness', () {
      expect(theme.brightness, Brightness.light);
    });

    test('scaffold background is cream', () {
      expect(theme.scaffoldBackgroundColor, BrandColors.cream);
    });

    test('primary color is deep ink', () {
      expect(theme.colorScheme.primary, BrandColors.deepInk);
    });

    test('secondary color is gold', () {
      expect(theme.colorScheme.secondary, BrandColors.gold);
    });

    test('error color is brand error red', () {
      expect(theme.colorScheme.error, BrandColors.error);
    });

    test('has a displayLarge type scale', () {
      expect(theme.textTheme.displayLarge, isNotNull);
      expect(theme.textTheme.displayLarge!.fontSize, 32);
      expect(theme.textTheme.displayLarge!.fontWeight, FontWeight.w700);
    });

    test('has a bodyLarge type scale', () {
      expect(theme.textTheme.bodyLarge, isNotNull);
      expect(theme.textTheme.bodyLarge!.fontSize, 16);
    });
  });

  group('AppTheme.dark()', () {
    final theme = AppTheme.dark();

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('is dark brightness', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('scaffold background is deep ink', () {
      expect(theme.scaffoldBackgroundColor, BrandColors.deepInk);
    });

    test('primary color is gold', () {
      expect(theme.colorScheme.primary, BrandColors.gold);
    });

    test('displayLarge text is cream in dark mode', () {
      expect(theme.textTheme.displayLarge, isNotNull);
      expect(theme.textTheme.displayLarge!.color, BrandColors.cream);
    });
  });
}
