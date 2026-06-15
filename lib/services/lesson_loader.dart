import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/lesson.dart';

/// Loads a lesson JSON from bundled assets. Day-to-path mapping is
/// hardcoded for now; the U15 content pipeline will replace this with
/// a generated index.
class LessonLoader {
  static const Map<int, String> _paths = {
    1: 'assets/lessons/day_01_knight_moves.json',
    2: 'assets/lessons/day_02_piece_values.json',
    3: 'assets/lessons/day_03_pin_tactic.json',
  };

  /// Returns the lesson for [day] (1-indexed).
  /// Throws [StateError] if no lesson is bundled for that day.
  Future<Lesson> load(int day) async {
    final path = _paths[day];
    if (path == null) {
      throw StateError('No lesson bundled for day $day');
    }
    final raw = await rootBundle.loadString(path);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return Lesson.fromJson(json);
  }
}
