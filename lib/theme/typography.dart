import 'package:flutter/material.dart';

import 'brand.dart';

/// Type scale for chess-do-it. Uses platform default font (San Francisco
/// on iOS, Roboto on Android) for now. Inter bundling comes in U2
/// alongside the Lottie animation pipeline.
///
/// Every style sets an explicit [color] so widgets that reference
/// `Theme.of(context).textTheme.X` don't fall back to platform
/// default colors (which can render as white-on-white in Material
/// 3 when the textTheme is overridden with color-less TextStyles).
class AppTypography {
  AppTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: BrandColors.deepInk,
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: BrandColors.deepInk,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: BrandColors.deepInk,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: BrandColors.deepInk,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: BrandColors.deepInk,
  );
}
