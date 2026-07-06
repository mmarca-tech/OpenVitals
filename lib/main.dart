import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'di/providers.dart';

/// App entry point.
///
/// Resolves the platform [SharedPreferences] instance up front and injects it
/// into the Riverpod graph via [sharedPreferencesProvider] (the standard
/// bootstrap override pattern documented on that provider). Drift and the
/// health data source resolve lazily from their own providers on first use, so
/// they do not need to be awaited here.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const OpenVitalsApp(),
    ),
  );
}
