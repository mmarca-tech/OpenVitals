import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'bootstrap/reminder_bootstrap.dart';
import 'di/providers.dart';
import 'features/imports/route_import_intent.dart';

/// App entry point.
///
/// Resolves the platform [SharedPreferences] instance up front and injects it
/// into the Riverpod graph via [sharedPreferencesProvider] (the standard
/// bootstrap override pattern documented on that provider). Drift and the
/// health data source resolve lazily from their own providers on first use, so
/// they do not need to be awaited here.
///
/// The container is created explicitly rather than by [ProviderScope] so that
/// [bootstrapReminders] can read it. Reminders come up *after* [runApp] and are
/// never awaited: re-arming an alarm touches Health Connect and must not hold
/// the first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Receives activity-recording notification-button presses relayed from the
  // foreground-service isolate (see activity_recording_task_handler.dart).
  FlutterForegroundTask.initCommunicationPort();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      // Drains any route file the app was opened with ("Open with" on a
      // .gpx/.kml/.kmz/.fit) into the activity-entry form — the Kotlin
      // `ExternalRouteImportRequest` path.
      child: const RouteImportIntentBootstrap(child: OpenVitalsApp()),
    ),
  );

  unawaited(bootstrapReminders(container));
}
