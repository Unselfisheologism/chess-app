import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/puzzle.dart';

/// Loads the bundled daily-puzzle set and picks today's puzzle by
/// day-of-launch (modulo the bundle size).
class PuzzleService {
  List<Puzzle>? _cache;

  Future<List<Puzzle>> _all() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/puzzles/daily_puzzles.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['puzzles'] as List<dynamic>)
        .map((p) => Puzzle.fromJson(p as Map<String, dynamic>))
        .toList();
    _cache = list;
    return list;
  }

  /// Pick today's puzzle. [day] is 1-indexed; when [day] exceeds the
  /// bundled count, we wrap around so the user always gets a puzzle.
  Future<Puzzle?> pickTodaysPuzzle(int day) async {
    final all = await _all();
    if (all.isEmpty) return null;
    final index = ((day - 1) % all.length);
    return all[index];
  }
}
