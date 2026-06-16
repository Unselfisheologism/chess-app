import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single analytics event. Stored in shared_preferences as part
/// of a bounded ring of [kMaxEvents] entries. Pure local storage —
/// **nothing leaves the device** (per NFR6).
@immutable
class AnalyticsEvent {
  final DateTime timestamp;
  final String type;
  final Map<String, Object?> properties;

  const AnalyticsEvent({
    required this.timestamp,
    required this.type,
    this.properties = const {},
  });

  Map<String, dynamic> toJson() => {
        't': timestamp.toIso8601String(),
        'type': type,
        'p': properties,
      };

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      timestamp: DateTime.parse(json['t'] as String),
      type: json['type'] as String,
      properties:
          (json['p'] as Map<String, dynamic>?)?.cast<String, Object?>() ??
              const {},
    );
  }
}

/// Local analytics log. All storage is on-device.
///
/// Tracking is fire-and-forget; `track()` never blocks the UI
/// thread on a slow SharedPreferences write (the call returns a
/// Future but callers should not `await` it on hot paths).
class AnalyticsService {
  static const _kKey = 'chess_do_it_analytics_v1';
  static const _kMaxEvents = 200;

  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  /// Record an event. [type] is a short dot-namespaced string
  /// (e.g. 'lesson_start'). [properties] is an arbitrary payload
  /// — keep it small and JSON-serializable.
  Future<void> track(
    String type, {
    Map<String, Object?> properties = const {},
  }) async {
    final event = AnalyticsEvent(
      timestamp: DateTime.now(),
      type: type,
      properties: properties,
    );
    try {
      final prefs = await _getPrefsWithRetry();
      final raw = prefs.getStringList(_kKey) ?? <String>[];
      raw.add(jsonEncode(event.toJson()));
      // Bound the log so it doesn't grow without limit.
      if (raw.length > _kMaxEvents) {
        raw.removeRange(0, raw.length - _kMaxEvents);
      }
      await prefs.setStringList(_kKey, raw);
      if (kDebugMode) {
        // eslint-disable-next-line avoid_print
        print('[analytics] $type ${event.properties.isEmpty ? '' : event.properties}');
      }
    } catch (e) {
      // Analytics is best-effort; never crash the user-facing flow.
      if (kDebugMode) print('[analytics] track failed: $e');
    }
  }

  /// Returns all stored events, oldest first.
  Future<List<AnalyticsEvent>> read() async {
    try {
      final prefs = await _getPrefsWithRetry();
      final raw = prefs.getStringList(_kKey) ?? <String>[];
      final out = <AnalyticsEvent>[];
      for (final line in raw) {
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          out.add(AnalyticsEvent.fromJson(json));
        } catch (_) {
          // Skip malformed entries silently.
        }
      }
      return out;
    } catch (e) {
      if (kDebugMode) print('[analytics] read failed: $e');
      return <AnalyticsEvent>[]; // empty list on failure
    }
  }

  /// Wipe the log. Useful for a hidden "reset analytics" button
  /// in a debug screen.
  Future<void> clear() async {
    final prefs = await _getPrefsWithRetry();
    await prefs.remove(_kKey);
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
}
