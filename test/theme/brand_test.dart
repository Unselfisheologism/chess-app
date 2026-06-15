import 'package:chess_do_it/theme/brand.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandColors', () {
    test('deepInk has the expected ARGB components', () {
      expect(BrandColors.deepInk.alpha, 0xFF);
      expect(BrandColors.deepInk.red, 0x0E);
      expect(BrandColors.deepInk.green, 0x11);
      expect(BrandColors.deepInk.blue, 0x16);
    });

    test('cream has the expected ARGB components', () {
      expect(BrandColors.cream.alpha, 0xFF);
      expect(BrandColors.cream.red, 0xF5);
      expect(BrandColors.cream.green, 0xEB);
      expect(BrandColors.cream.blue, 0xDC);
    });

    test('gold has the expected ARGB components', () {
      expect(BrandColors.gold.alpha, 0xFF);
      expect(BrandColors.gold.red, 0xE0);
      expect(BrandColors.gold.green, 0xB2);
      expect(BrandColors.gold.blue, 0x3C);
    });

    test('success has the expected ARGB components', () {
      expect(BrandColors.success.alpha, 0xFF);
      expect(BrandColors.success.red, 0x3D);
      expect(BrandColors.success.green, 0xBC);
      expect(BrandColors.success.blue, 0x73);
    });

    test('error has the expected ARGB components', () {
      expect(BrandColors.error.alpha, 0xFF);
      expect(BrandColors.error.red, 0xE7);
      expect(BrandColors.error.green, 0x4C);
      expect(BrandColors.error.blue, 0x3C);
    });

    test('lockedGrey has the expected ARGB components', () {
      expect(BrandColors.lockedGrey.alpha, 0xFF);
      expect(BrandColors.lockedGrey.red, 0x9A);
      expect(BrandColors.lockedGrey.green, 0xA0);
      expect(BrandColors.lockedGrey.blue, 0xA6);
    });
  });

  group('BrandMascot', () {
    test('codename is the chess-do-it placeholder', () {
      expect(BrandMascot.codename, 'chess-do-it');
    });
  });
}
