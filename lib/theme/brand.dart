import 'package:flutter/material.dart';

/// Brand color tokens for chess-do-it.
///
/// Source of truth for the app's color palette. All colors are 0xAARRGGBB
/// constants; widgets reference these instead of hardcoding hex values.
class BrandColors {
  BrandColors._();

  static const Color deepInk = Color(0xFF0E1116);
  static const Color cream = Color(0xFFF5EBDC);
  static const Color gold = Color(0xFFE0B23C);
  static const Color success = Color(0xFF3DBC73);
  static const Color error = Color(0xFFE74C3C);
  static const Color lockedGrey = Color(0xFF9AA0A6);
}

/// Brand identity tokens. The mascot / display name placeholder is
/// decided in a later brand pass; for now `chess-do-it` is the codename
/// shown on the bootstrap screen.
class BrandMascot {
  BrandMascot._();

  static const String codename = 'chess-do-it';
}
