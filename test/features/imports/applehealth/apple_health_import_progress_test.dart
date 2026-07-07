import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_models.dart';

void main() {
  group('AppleHealthImportProgress.percent', () {
    test('is unavailable until selected record total is known', () {
      const progress = AppleHealthImportProgress(
        phase: AppleHealthImportPhase.parsing,
        convertedRecords: 4,
      );

      expect(progress.percent, isNull);
    });

    test('uses selected record total as denominator', () {
      const progress = AppleHealthImportProgress(
        phase: AppleHealthImportPhase.parsing,
        convertedRecords: 6,
        notSelectedRecords: 2,
        expectedSelectedRecords: 8,
      );

      expect(progress.percent, 44);
    });

    test('does not count unselected records or generic skips as progress', () {
      const progress = AppleHealthImportProgress(
        phase: AppleHealthImportPhase.parsing,
        convertedRecords: 10,
        notSelectedRecords: 6,
        skippedRecords: 3,
        expectedSelectedRecords: 8,
      );

      expect(progress.percent, 44);
    });

    test('reserves final steps for duplicate checks, writing and report', () {
      const duplicateCheck = AppleHealthImportProgress(
        phase: AppleHealthImportPhase.checkingDuplicates,
        convertedRecords: 8,
        expectedSelectedRecords: 8,
      );

      expect(duplicateCheck.percent, 88);
      expect(
        duplicateCheck.copyWith(phase: AppleHealthImportPhase.writing).percent,
        92,
      );
      expect(
        duplicateCheck
            .copyWith(phase: AppleHealthImportPhase.buildingReport)
            .percent,
        98,
      );
      expect(
        duplicateCheck.copyWith(phase: AppleHealthImportPhase.complete).percent,
        100,
      );
    });
  });
}
