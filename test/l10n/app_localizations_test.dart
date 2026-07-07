// Verifies the generated [AppLocalizations] is wired to the ARB catalogs:
// every declared locale loads, translations actually differ between languages
// (not just the English fallback), and placeholder messages interpolate.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openvitals/l10n/app_localizations.dart';

void main() {
  test('all five app languages are supported', () {
    final codes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();
    expect(codes, containsAll(<String>['en', 'de', 'es', 'it', 'et']));
  });

  test('English and German load with distinct translations', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final de = await AppLocalizations.delegate.load(const Locale('de'));

    expect(en.settingsDisplayGroupTitle, 'Display');
    expect(de.settingsDisplayGroupTitle, 'Anzeige');
    // The whole point of wiring l10n: the German value is a real translation,
    // not the English fallback.
    expect(de.settingsDisplayGroupTitle, isNot(en.settingsDisplayGroupTitle));
  });

  test('Spanish, Italian and Estonian also carry real translations', () async {
    final es = await AppLocalizations.delegate.load(const Locale('es'));
    final it = await AppLocalizations.delegate.load(const Locale('it'));
    final et = await AppLocalizations.delegate.load(const Locale('et'));

    expect(es.screenSettings, 'Ajustes');
    expect(it.screenSettings, 'Impostazioni');
    expect(et.screenSettings, 'Seaded');
  });

  test('placeholder messages interpolate their arguments', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    // Single String arg (Android `%1$s`).
    expect(en.cdExpandDrinkCategory('Coffee'), 'Expand Coffee');
    // Two int args (Android `%1$d ... %2$d`).
    expect(en.dashboardSensorStatusActiveConnected(2, 3), '2 active • 3 connected');
  });
}
