import 'package:chess_do_it/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AnalyticsService.instance.clear();
  });

  group('AnalyticsService.track', () {
    test('stores events with timestamp, type, properties', () async {
      await AnalyticsService.instance.track('test_event',
          properties: {'key': 'value'});
      final events = await AnalyticsService.instance.read();
      expect(events.length, 1);
      expect(events.first.type, 'test_event');
      expect(events.first.properties['key'], 'value');
    });

    test('append-only: multiple track calls accumulate', () async {
      await AnalyticsService.instance.track('a');
      await AnalyticsService.instance.track('b');
      await AnalyticsService.instance.track('c');
      final events = await AnalyticsService.instance.read();
      expect(events.map((e) => e.type).toList(), ['a', 'b', 'c']);
    });

    test('properties is optional and defaults to empty', () async {
      await AnalyticsService.instance.track('no_props');
      final events = await AnalyticsService.instance.read();
      expect(events.first.properties, isEmpty);
    });

    test('clear() wipes the log', () async {
      await AnalyticsService.instance.track('before_clear');
      await AnalyticsService.instance.clear();
      final events = await AnalyticsService.instance.read();
      expect(events, isEmpty);
    });

    test('caps at 200 events (ring buffer behavior)', () async {
      for (var i = 0; i < 250; i++) {
        await AnalyticsService.instance.track('e$i');
      }
      final events = await AnalyticsService.instance.read();
      expect(events.length, 200);
      // Oldest 50 were dropped; the first kept is e50.
      expect(events.first.type, 'e50');
      expect(events.last.type, 'e249');
    });

    test('read() skips malformed entries without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'chess_do_it_analytics_v1': [
          'not valid json',
          '{"t":"2026-06-15T10:00:00.000Z","type":"valid","p":{}}',
        ],
      });
      final events = await AnalyticsService.instance.read();
      expect(events.length, 1);
      expect(events.first.type, 'valid');
    });
  });
}
