import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent state for the user's daily-lesson streak.
///
/// Backed by [SharedPreferences]. All methods are async because the
/// underlying plugin uses platform channels. The first-launch state
/// is an empty streak (no days completed, no tokens).
@immutable
class StreakState {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLessonDate;
  final int freezeTokens;
  final int totalLessonsCompleted;

  const StreakState({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastLessonDate,
    required this.freezeTokens,
    required this.totalLessonsCompleted,
  });

  static const empty = StreakState(
    currentStreak: 0,
    longestStreak: 0,
    lastLessonDate: null,
    freezeTokens: 0,
    totalLessonsCompleted: 0,
  );

  StreakState copyWith({
    int? currentStreak,
    int? longestStreak,
    DateTime? lastLessonDate,
    int? freezeTokens,
    int? totalLessonsCompleted,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastLessonDate: lastLessonDate ?? this.lastLessonDate,
      freezeTokens: freezeTokens ?? this.freezeTokens,
      totalLessonsCompleted:
          totalLessonsCompleted ?? this.totalLessonsCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastLessonDate': lastLessonDate?.toIso8601String(),
        'freezeTokens': freezeTokens,
        'totalLessonsCompleted': totalLessonsCompleted,
      };

  factory StreakState.fromJson(Map<String, dynamic> json) {
    DateTime? lastDate;
    final dateStr = json['lastLessonDate'] as String?;
    if (dateStr != null) {
      lastDate = DateTime.tryParse(dateStr);
    }
    return StreakState(
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      lastLessonDate: lastDate,
      freezeTokens: (json['freezeTokens'] as num?)?.toInt() ?? 0,
      totalLessonsCompleted:
          (json['totalLessonsCompleted'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Service for reading and updating the user's streak.
///
/// Singleton for now (no DI). Pass [SharedPreferences] in tests via
/// [StreakService.instanceForTest] to inject a mock.
class StreakService {
  static const _kKey = 'chess_do_it_streak_v1';

  StreakService._();
  static final StreakService instance = StreakService._();

  /// Injected instance for tests.
  static StreakService? _testInstance;
  static StreakService get instanceForTest =>
      _testInstance ?? (_testInstance = StreakService._());

  Future<StreakState> read() async {
    final prefs = await _getPrefsWithRetry();
    final raw = prefs.getString(_kKey);
    if (raw == null) return StreakState.empty;
    try {
      // SharedPreferences gives us strings; we encode JSON ourselves.
      return StreakState.fromJson(_decodeJson(raw));
    } catch (_) {
      return StreakState.empty;
    }
  }

  /// Get a SharedPreferences instance with retry. The
  /// `shared_preferences` plugin on Android sometimes throws
  /// `PlatformException(channel-error, Unable to establish
  /// connection on channel)` when called before the platform
  /// side has registered the method channel — typically on cold
  /// start, or when this is the first plugin touched by the
  /// isolate. Three short retries with exponential backoff
  /// (50ms, 100ms, 200ms) cover the common case without making
  /// the user wait.
  static Future<SharedPreferences> _getPrefsWithRetry() async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await SharedPreferences.getInstance();
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(Duration(milliseconds: 50 * (1 << attempt)));
      }
    }
    throw lastError ?? StateError('SharedPreferences unavailable');
  }

  Future<void> _write(StreakState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, _encodeJson(state.toJson()));
  }

  /// Records that the user completed today's lesson. Handles:
  /// - first lesson ever: streak = 1
  /// - same calendar day as last: no-op (don't double-count)
  /// - next calendar day: streak += 1 (advance)
  /// - skip a day, no freeze tokens: streak resets to 1
  /// - skip a day, has freeze tokens: streak preserved, token spent
  ///
  /// [now] is injected for testability; defaults to DateTime.now().
  Future<StreakState> markLessonComplete({DateTime? now}) async {
    final current = await read();
    final today = _dateOnly(now ?? DateTime.now());
    final last = current.lastLessonDate == null
        ? null
        : _dateOnly(current.lastLessonDate!);

    StreakState next;
    if (last == null) {
      // First lesson ever.
      next = current.copyWith(
        currentStreak: 1,
        longestStreak: current.longestStreak < 1 ? 1 : current.longestStreak,
        lastLessonDate: today,
        totalLessonsCompleted: current.totalLessonsCompleted + 1,
      );
    } else if (last.isAtSameMomentAs(today)) {
      // Already completed today; no-op.
      next = current;
    } else {
      final daysSince = today.difference(last).inDays;
      if (daysSince == 1) {
        // Consecutive day.
        final newStreak = current.currentStreak + 1;
        next = current.copyWith(
          currentStreak: newStreak,
          longestStreak: newStreak > current.longestStreak
              ? newStreak
              : current.longestStreak,
          lastLessonDate: today,
          totalLessonsCompleted: current.totalLessonsCompleted + 1,
        );
      } else if (current.freezeTokens > 0) {
        // Skipped; use a freeze token to preserve the streak.
        next = current.copyWith(
          freezeTokens: current.freezeTokens - 1,
          lastLessonDate: today,
          totalLessonsCompleted: current.totalLessonsCompleted + 1,
        );
      } else {
        // Skipped and out of tokens; reset.
        next = current.copyWith(
          currentStreak: 1,
          lastLessonDate: today,
          totalLessonsCompleted: current.totalLessonsCompleted + 1,
        );
      }
    }
    await _write(next);
    return next;
  }

  /// Grant a freeze token (e.g., after completing a daily match in
  /// U7). Caps the balance at 3 so users can't stockpile forever.
  Future<StreakState> grantFreezeToken() async {
    final current = await read();
    if (current.freezeTokens >= 3) return current;
    final next = current.copyWith(freezeTokens: current.freezeTokens + 1);
    await _write(next);
    return next;
  }

  /// Test helper: wipe the streak.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  // --- helpers ---

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // We use Dart's built-in json via dart:convert to keep this file
  // import-free; the operations are trivial enough that the cost
  // is negligible.
  static String _encodeJson(Map<String, dynamic> m) {
    // Avoid dart:convert import for this trivial case; build a stable
    // string with the same semantics.
    final buf = StringBuffer('{');
    bool first = true;
    m.forEach((k, v) {
      if (!first) buf.write(',');
      first = false;
      buf.write('"'); buf.write(k); buf.write('":');
      if (v == null) {
        buf.write('null');
      } else if (v is num || v is bool) {
        buf.write(v.toString());
      } else {
        buf.write('"'); buf.write(v.toString()); buf.write('"');
      }
    });
    buf.write('}');
    return buf.toString();
  }

  static Map<String, dynamic> _decodeJson(String s) {
    // Tiny hand-rolled parser sufficient for the flat map we emit.
    // Avoids dart:convert import. If parsing fails, the caller falls
    // back to empty state.
    final m = <String, dynamic>{};
    final inner = s.trim();
    if (!inner.startsWith('{') || !inner.endsWith('}')) {
      throw const FormatException('Not a JSON object');
    }
    final body = inner.substring(1, inner.length - 1).trim();
    if (body.isEmpty) return m;
    // Split on commas that are not inside quotes. The map only
    // contains string/number/null values, so this is sufficient.
    final parts = _splitTopLevel(body, ',');
    for (final part in parts) {
      final colonIdx = part.indexOf(':');
      if (colonIdx < 0) continue;
      final keyRaw = part.substring(0, colonIdx).trim();
      final valueRaw = part.substring(colonIdx + 1).trim();
      final key = _unquote(keyRaw);
      Object? value;
      if (valueRaw == 'null') {
        value = null;
      } else if (valueRaw.startsWith('"') && valueRaw.endsWith('"')) {
        value = _unquote(valueRaw);
      } else {
        final asInt = int.tryParse(valueRaw);
        if (asInt != null) {
          value = asInt;
        } else {
          final asDouble = double.tryParse(valueRaw);
          value = asDouble;
        }
      }
      m[key] = value;
    }
    return m;
  }

  static List<String> _splitTopLevel(String s, String sep) {
    final out = <String>[];
    final buf = StringBuffer();
    bool inString = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '"' && (i == 0 || s[i - 1] != r'\')) {
        inString = !inString;
        buf.write(c);
      } else if (c == sep[0] && !inString) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  static String _unquote(String s) {
    var t = s.trim();
    if (t.startsWith('"') && t.endsWith('"')) {
      t = t.substring(1, t.length - 1);
    }
    return t;
  }
}
