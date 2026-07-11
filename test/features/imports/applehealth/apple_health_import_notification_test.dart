import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:openvitals/features/imports/applehealth/apple_health_import_models.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_notification.dart';
import 'package:openvitals/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('percent + a known export size shows scan progress', () {
    // Kotlin: `settings_apple_health_import_notification_text_with_scan_percent`
    // — while parsing, "scanned / expected elements" is the only denominator
    // that means anything.
    const progress = AppleHealthImportProgress(
      phase: AppleHealthImportPhase.parsing,
      parsedRecords: 40,
      convertedRecords: 20,
      importedRecords: 8,
      expectedSelectedRecords: 50,
    );

    final text = appleHealthImportNotificationText(
      l10n,
      progress,
      expectedParsedElements: 100,
    );

    expect(
      text,
      l10n.settingsAppleHealthImportNotificationTextWithScanPercent(
        progress.percent!,
        l10n.settingsAppleHealthImportProgressParsing,
        40,
        100,
        8,
      ),
    );
    expect(text, contains('40/100'));
  });

  test('percent without a known export size shows selected-record progress', () {
    const progress = AppleHealthImportProgress(
      phase: AppleHealthImportPhase.writing,
      parsedRecords: 40,
      convertedRecords: 30,
      notSelectedRecords: 5,
      importedRecords: 8,
      expectedSelectedRecords: 50,
    );

    final text = appleHealthImportNotificationText(l10n, progress);

    expect(
      text,
      l10n.settingsAppleHealthImportNotificationTextWithPercent(
        progress.percent!,
        l10n.settingsAppleHealthImportProgressWriting,
        25, // selectedPreparedRecords: converted - notSelected
        50,
        8,
      ),
    );
    expect(text, contains('25/50'));
  });

  test('no percent falls back to phase + scanned/imported counters', () {
    // No expected total ⇒ `percent` is null (Kotlin's `?: getString(...)` arm).
    const progress = AppleHealthImportProgress(
      phase: AppleHealthImportPhase.converting,
      parsedRecords: 40,
      parsedWorkouts: 2,
      importedRecords: 8,
    );

    expect(progress.percent, isNull);
    expect(
      appleHealthImportNotificationText(
        l10n,
        progress,
        expectedParsedElements: 100,
      ),
      l10n.settingsAppleHealthImportNotificationText(
        l10n.settingsAppleHealthImportProgressConverting,
        42,
        8,
      ),
    );
  });

  test('the phase label is the one the card shows', () {
    expect(
      appleHealthImportPhaseLabel(l10n, AppleHealthImportPhase.complete),
      l10n.settingsAppleHealthImportProgressComplete,
    );
    expect(
      appleHealthImportPhaseLabel(l10n, AppleHealthImportPhase.checkingDuplicates),
      l10n.settingsAppleHealthImportProgressCheckingDuplicates,
    );
  });
}
