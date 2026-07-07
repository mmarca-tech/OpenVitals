import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/data/prefs/preferences_repository.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/preferences/app_theme_mode.dart';
import 'package:openvitals/features/settings/settings_screen.dart';
import 'package:openvitals/features/settings/settings_section.dart';
import 'package:openvitals/features/settings/settings_section_screen.dart';
import 'package:openvitals/l10n/app_localizations.dart';

Future<(Widget, SharedPreferences)> _bootstrap(Widget child) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return (
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
    prefs,
  );
}

void main() {
  testWidgets('settings root renders the section cards', (tester) async {
    final (widget, _) = await _bootstrap(const SettingsScreen());
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Display'), findsOneWidget);
    expect(find.text('Health Connect'), findsOneWidget);
    expect(find.text('Nutrition'), findsOneWidget);
  });

  testWidgets('selecting a theme mode persists through the repository',
      (tester) async {
    final (widget, prefs) = await _bootstrap(
      const SettingsSectionScreen(section: SettingsSection.display),
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // Sanity: it starts at the default (system).
    expect(PreferencesRepository(prefs).appThemeMode, AppThemeMode.system);

    final darkChip = find.text('Dark');
    await tester.ensureVisible(darkChip);
    await tester.tap(darkChip);
    await tester.pumpAndSettle();

    expect(PreferencesRepository(prefs).appThemeMode, AppThemeMode.dark);
  });
}
