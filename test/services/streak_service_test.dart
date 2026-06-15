import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_do_it/services/streak_service.dart';

void main() {
  group('StreakService.markLessonComplete', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // Reset the singleton between tests by clearing storage.
      await StreakService.instance.reset();
    });

    test('first lesson ever: streak = 1', () async {
      final now = DateTime(2026, 6, 15);
      final state = await StreakService.instance.markLessonComplete(now: now);
      expect(state.currentStreak, 1);
      expect(state.longestStreak, 1);
      expect(state.lastLessonDate, DateTime(2026, 6, 15));
      expect(state.totalLessonsCompleted, 1);
    });

    test('consecutive day: streak += 1', () async {
      await StreakService.instance
          .markLessonComplete(now: DateTime(2026, 6, 15));
      final next = await StreakService.instance
          .markLessonComplete(now: DateTime(2026, 6, 16));
      expect(next.currentStreak, 2);
      expect(next.longestStreak, 2);
    });

    test('same day: no double-count', () async {
      await StreakService.instance
          .markLessonComplete(now: DateTime(2026, 6, 15, 9));
      final again = await StreakService.instance
          .markLessonComplete(now: DateTime(2026, 6, 15, 21));
      expect(again.currentStreak, 1);
      expect(again.totalLessonsCompleted, 1);
    });

    test('skip a day with no tokens: streak resets to 1', () async {
      await StreakService.instance
          .markLessonComplete(now: DateTime(2026, 6, 15));
      await StreakService.instance
          .markLessonComplete(now: DateTime(2026, 6, 16));
      // Skipped 17th
      final s = await StreakService.instance
          .markLessonComplete(now: DateTime(2026, 6, 18));
      expect(s.currentStreak, 1);
      expect(s.longestStreak, 2); // longest preserved
    });

    test('skip a day with a token: token spent, streak preserved', () async {
      await StreakService.instance
          .markLessonComplete(now: DateTime(2026, 6, 15));
      await StreakService.instance.grantFreezeToken();
      await StreakService.instance
          .markLessonComplete(now: DateTime(2026, 6, 18));
      final s = await StreakService.instance.read();
      expect(s.freezeTokens, 0);
      expect(s.currentStreak, 1); // last date = 18, gap preserved
    });
  });

  group('StreakService.grantFreezeToken', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await StreakService.instance.reset();
    });

    test('caps at 3', () async {
      for (var i = 0; i < 5; i++) {
        await StreakService.instance.grantFreezeToken();
      }
      final s = await StreakService.instance.read();
      expect(s.freezeTokens, 3);
    });
  });
}
