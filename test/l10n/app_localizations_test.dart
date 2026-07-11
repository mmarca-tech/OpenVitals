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

  // PINS gen-l10n's template-fallback semantics, which the whole ARB-native
  // cutover rests on: the locale ARBs are genuinely PARTIAL, and a key a locale
  // omits must fall back to the English template message — NOT to a blank
  // string, and NOT to a build error.
  //
  // `settingsAppleHealthImportRoutesIncomplete` is currently untranslated in all
  // four locales (it is one of the three strings `flutter gen-l10n` reports as
  // `"de": 3 untranslated message(s).`). It used to be back-filled with English
  // INTO the ARBs by `tool/xml_to_arb.dart`, which made every catalog look 100%
  // complete; now the key is simply absent and gen-l10n supplies the fallback.
  //
  // If a future Flutter changes `_generateBaseClassFile` so a missing message no
  // longer falls back to the template, this test fails loudly instead of the app
  // silently shipping empty strings to every non-English user.
  test('an untranslated key falls back to the English template message',
      () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    for (final code in <String>['de', 'es', 'it', 'et']) {
      final l10n = await AppLocalizations.delegate.load(Locale(code));

      expect(
        l10n.settingsAppleHealthImportRoutesIncomplete,
        isNotEmpty,
        reason: '$code fell back to a BLANK string, not the template',
      );
      expect(
        l10n.settingsAppleHealthImportRoutesIncomplete,
        en.settingsAppleHealthImportRoutesIncomplete,
        reason: '$code did not fall back to the English template message; '
            'gen-l10n fallback semantics have changed',
      );
    }
  });
}
