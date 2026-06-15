import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/analytics_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire-and-forget app-open tracking. Doesn't block the UI.
  unawaited(AnalyticsService.instance.track('app_open'));
  runApp(const ChessDoItApp());
}
