import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/data/repository/contract/apple_health_import_repository.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_models.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_records.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_service.dart';

class FakeAppleHealthImportRepository implements AppleHealthImportRepository {
  FakeAppleHealthImportRepository({
    this.mindfulnessAvailable = true,
    this.matchAgainstInserted = false,
    this.matcher,
  });

  final bool mindfulnessAvailable;
  final bool matchAgainstInserted;
  final Set<String> Function(String recordType, Set<String> wantedIds)? matcher;

  final List<List<ImportRecord>> insertedBatches = [];
  final Set<String> insertedClientRecordIds = {};
  final List<({String recordType, Set<String> wantedIds})> queried = [];

  List<ImportRecord> get insertedRecords =>
      insertedBatches.expand((batch) => batch).toList();

  @override
  bool isMindfulnessAvailable() => mindfulnessAvailable;

  @override
  Future<void> insertImportedRecords(List<ImportRecord> records) async {
    insertedBatches.add(records);
    for (final record in records) {
      insertedClientRecordIds.add(record.clientRecordId);
    }
  }

  @override
  Future<Set<String>> findMatchingImportedClientRecordIds(
    String recordType,
    DateTime start,
    DateTime end,
    Set<String> wantedIds,
  ) async {
    queried.add((recordType: recordType, wantedIds: wantedIds));
    if (matcher != null) return matcher!(recordType, wantedIds);
    if (matchAgainstInserted) {
      return wantedIds.intersection(insertedClientRecordIds);
    }
    return const {};
  }
}

List<int> zipExport(
  String xml, {
  Map<String, String> extraFiles = const {},
  bool extraFilesBeforeXml = false,
}) {
  final archive = Archive();
  void writeExtras() {
    extraFiles.forEach((path, contents) {
      archive.add(ArchiveFile.string(path, contents));
    });
  }

  if (extraFilesBeforeXml) writeExtras();
  archive.add(ArchiveFile.string('apple_health_export/export.xml', xml));
  if (!extraFilesBeforeXml) writeExtras();
  return ZipEncoder().encodeBytes(archive);
}

String heartRateExport(int count, {(int, int)? duplicateIndexOf}) {
  final buffer = StringBuffer('<HealthData>');
  for (var index = 0; index < count; index++) {
    final effective = duplicateIndexOf != null && index == duplicateIndexOf.$1
        ? duplicateIndexOf.$2
        : index;
    final hour = (effective ~/ 60).toString().padLeft(2, '0');
    final minute = (effective % 60).toString().padLeft(2, '0');
    buffer.write(
      '<Record type="HKQuantityTypeIdentifierHeartRate" sourceName="Watch" '
      'startDate="2026-01-01 $hour:$minute:00 +0000" '
      'endDate="2026-01-01 $hour:$minute:00 +0000" unit="count/min" value="62" />',
    );
  }
  buffer.write('</HealthData>');
  return buffer.toString();
}

void main() {
  group('AppleHealthImportService', () {
    test('skips duplicate records inside same export and includes report',
        () async {
      const xml = '''
        <HealthData>
          <Record type="HKQuantityTypeIdentifierStepCount" sourceName="Phone"
            startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:10:00 +0000"
            unit="count" value="100" />
          <Record type="HKQuantityTypeIdentifierStepCount" sourceName="Phone"
            startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:10:00 +0000"
            unit="count" value="100" />
        </HealthData>
      ''';
      final repository = FakeAppleHealthImportRepository();
      final phases = <AppleHealthImportPhase>[];

      final result = await AppleHealthImportService(repository)
          .importAppleHealthExport(utf8.encode(xml),
              onProgress: (progress) => phases.add(progress.phase));

      expect(result.parsedRecords, 2);
      expect(result.importedRecords, 1);
      expect(result.duplicateSkippedRecords, 1);
      expect(phases, contains(AppleHealthImportPhase.parsing));
      expect(phases, contains(AppleHealthImportPhase.converting));
      expect(phases, contains(AppleHealthImportPhase.checkingDuplicates));
      expect(phases, contains(AppleHealthImportPhase.writing));
      expect(phases, contains(AppleHealthImportPhase.buildingReport));
      final report = result.shareableReportText;
      expect(report, contains('Stage started: Scanning export'));
      expect(report, contains('Stage finished: Scanning export'));
      expect(report, contains('Stage started: Checking duplicates'));
      expect(report, contains('Stage finished: Checking duplicates'));
      expect(report, contains('Stage started: Writing records'));
      expect(report, contains('Stage finished: Writing records'));
      expect(report, contains('Stage started: Building report'));
      expect(report, contains('Stage finished: Building report'));
      expect(report, contains('duplicate_in_file'));
      expect(repository.insertedBatches.length, 1);
      expect(repository.insertedBatches.single.single, isA<StepsImportRecord>());
    });

    test('analysis detects import categories without writing', () async {
      const xml = '''
        <HealthData>
          <Record type="HKQuantityTypeIdentifierStepCount" sourceName="Phone"
            startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:10:00 +0000"
            unit="count" value="100" />
          <Record type="HKQuantityTypeIdentifierBodyMass" sourceName="Scale"
            startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:00:00 +0000"
            unit="kg" value="70" />
        </HealthData>
      ''';
      final repository = FakeAppleHealthImportRepository();

      final result = await AppleHealthImportService(repository)
          .analyzeAppleHealthExport(utf8.encode(xml));

      expect(result.parsedRecords, 2);
      expect(result.convertedRecords, 2);
      expect(
        result.categorySummaries.map((it) => it.category).toSet(),
        {AppleHealthImportCategory.activity, AppleHealthImportCategory.body},
      );
      expect(repository.insertedBatches, isEmpty);
    });

    test('analysis detects route categories without parsing gpx geometry',
        () async {
      const xml = '''
        <HealthData>
          <Workout workoutActivityType="HKWorkoutActivityTypeRunning" sourceName="Apple Watch"
            startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:30:00 +0000"
            duration="30" durationUnit="min">
            <WorkoutRoute sourceName="Apple Watch"
              startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:30:00 +0000">
              <FileReference path="/workout-routes/route_2026-01-01_8.00am.gpx" />
            </WorkoutRoute>
          </Workout>
        </HealthData>
      ''';
      final repository = FakeAppleHealthImportRepository();

      final result = await AppleHealthImportService(repository)
          .analyzeAppleHealthExport(zipExport(
        xml,
        extraFiles: {
          'apple_health_export/workout-routes/route_2026-01-01_8.00am.gpx':
              '<not-gpx>',
        },
      ));

      final workoutSummary = result.categorySummaries
          .firstWhere((it) => it.category == AppleHealthImportCategory.workouts);
      expect(result.parsedWorkouts, 1);
      expect(workoutSummary.convertedRecords, 1);
      expect(workoutSummary.routeSessions, 1);
      expect(result.shareableReportText, contains('parseRouteFiles=false'));
      expect(repository.insertedBatches, isEmpty);
    });

    test('imports only selected categories after analysis', () async {
      const xml = '''
        <HealthData>
          <Record type="HKQuantityTypeIdentifierStepCount" sourceName="Phone"
            startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:10:00 +0000"
            unit="count" value="100" />
          <Record type="HKQuantityTypeIdentifierBodyMass" sourceName="Scale"
            startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:00:00 +0000"
            unit="kg" value="70" />
        </HealthData>
      ''';
      final repository = FakeAppleHealthImportRepository();

      final result = await AppleHealthImportService(repository)
          .importAppleHealthExport(
        utf8.encode(xml),
        selectedCategories: {AppleHealthImportCategory.body},
      );

      expect(result.convertedRecords, 2);
      expect(result.importedRecords, 1);
      expect(result.notSelectedRecords, 1);
      expect(repository.insertedBatches.single.single,
          isA<WeightImportRecord>());
      expect(result.shareableReportText, contains('Not selected: 1'));
    });

    test('report aggregates repeated diagnostics and keeps later distinct '
        'groups', () async {
      final buffer = StringBuffer('<HealthData>');
      for (var index = 0; index < 205; index++) {
        final day = (1 + index ~/ 60).toString().padLeft(2, '0');
        final minute = (index % 60).toString().padLeft(2, '0');
        buffer.write(
          '<Record type="HKQuantityTypeIdentifierUnsupportedA" sourceName="Phone" '
          'startDate="2026-01-$day 08:$minute:00 +0000" '
          'endDate="2026-01-$day 08:$minute:01 +0000" unit="count" value="1" />',
        );
      }
      buffer.write(
        '<Record type="HKQuantityTypeIdentifierUnsupportedB" sourceName="Phone" '
        'startDate="2026-01-01 09:00:00 +0000" endDate="2026-01-01 09:00:01 +0000" '
        'unit="count" value="1" />',
      );
      buffer.write('</HealthData>');
      final repository = FakeAppleHealthImportRepository();

      final result = await AppleHealthImportService(repository)
          .importAppleHealthExport(utf8.encode(buffer.toString()));

      final report = result.shareableReportText;
      expect(result.unsupportedElements, 206);
      expect(report, contains('Logs'));
      expect(report, contains('Raw Diagnostic Log'));
      expect(report, contains('Grouped diagnostic types: 2; unsupported=206'));
      expect(
        report,
        contains(
            'count=205; reason=unsupported; appleType=HKQuantityTypeIdentifierUnsupportedA'),
      );
      expect(
        report,
        contains(
            'count=1; reason=unsupported; appleType=HKQuantityTypeIdentifierUnsupportedB'),
      );
      final rawMatches = RegExp(
        r'^\d+\. reason=unsupported; appleType=HKQuantityTypeIdentifierUnsupportedA',
        multiLine: true,
      ).allMatches(report).length;
      expect(rawMatches, 205);
      expect(report, isNot(contains('Diagnostics were truncated at 200 entries.')));
    });

    test('pipelines multiple batches in order and imports all records',
        () async {
      final repository = FakeAppleHealthImportRepository();
      final progress = <AppleHealthImportProgress>[];

      final result = await AppleHealthImportService(repository)
          .importAppleHealthExport(
        utf8.encode(heartRateExport(700)),
        onProgress: progress.add,
      );

      expect(result.parsedRecords, 700);
      expect(result.importedRecords, 700);
      expect(result.duplicateSkippedRecords, 0);
      expect(
        repository.insertedBatches.map((batch) => batch.length).toList(),
        [300, 300, 100],
      );
      final batchStartTimes = repository.insertedBatches
          .map((batch) => (batch.first as HeartRateImportRecord).startTime)
          .toList();
      expect(batchStartTimes[0].isBefore(batchStartTimes[1]), isTrue);
      expect(batchStartTimes[1].isBefore(batchStartTimes[2]), isTrue);
      expect(result.shareableReportText,
          contains('Imported Health Connect records: 700'));

      final phases = progress.map((it) => it.phase).toSet();
      expect(phases, contains(AppleHealthImportPhase.parsing));
      expect(phases, contains(AppleHealthImportPhase.converting));
      expect(phases, contains(AppleHealthImportPhase.checkingDuplicates));
      expect(phases, contains(AppleHealthImportPhase.writing));
      expect(phases, contains(AppleHealthImportPhase.buildingReport));
      final importedCounts = progress.map((it) => it.importedRecords).toList();
      final sorted = List<int>.of(importedCounts)..sort();
      expect(importedCounts, sorted);
      expect(importedCounts.last, 700);
    });

    test('skips duplicates that appear in a later batch of the same export',
        () async {
      final repository =
          FakeAppleHealthImportRepository(matchAgainstInserted: true);

      final result = await AppleHealthImportService(repository)
          .importAppleHealthExport(
        utf8.encode(heartRateExport(400, duplicateIndexOf: (350, 0))),
      );

      expect(result.parsedRecords, 400);
      expect(result.importedRecords, 399);
      expect(result.duplicateSkippedRecords, 1);
      expect(result.shareableReportText, contains('duplicate_existing'));
    });

    test('unions parallel duplicate check chunks across types and time spans',
        () async {
      const xml = '''
        <HealthData>
          <Record type="HKQuantityTypeIdentifierHeartRate" sourceName="Watch"
            startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:00:00 +0000"
            unit="count/min" value="62" />
          <Record type="HKQuantityTypeIdentifierHeartRate" sourceName="Watch"
            startDate="2026-01-02 08:00:00 +0000" endDate="2026-01-02 08:00:00 +0000"
            unit="count/min" value="63" />
          <Record type="HKQuantityTypeIdentifierBodyMass" sourceName="Scale"
            startDate="2026-01-01 09:00:00 +0000" endDate="2026-01-01 09:00:00 +0000"
            unit="kg" value="70" />
          <Record type="HKQuantityTypeIdentifierBodyMass" sourceName="Scale"
            startDate="2026-01-03 09:00:00 +0000" endDate="2026-01-03 09:00:00 +0000"
            unit="kg" value="71" />
        </HealthData>
      ''';
      final repository = FakeAppleHealthImportRepository(
        matcher: (recordType, wantedIds) =>
            recordType == 'HeartRateRecord' ? {wantedIds.first} : const {},
      );

      final result = await AppleHealthImportService(repository)
          .importAppleHealthExport(utf8.encode(xml));

      expect(repository.queried.length, 4);
      expect(
        repository.queried.where((q) => q.recordType == 'HeartRateRecord').length,
        2,
      );
      expect(
        repository.queried.where((q) => q.recordType == 'WeightRecord').length,
        2,
      );
      expect(result.duplicateSkippedRecords, 2);
      expect(result.importedRecords, 2);
      expect(
        repository.insertedRecords.every((it) => it is WeightImportRecord),
        isTrue,
      );
    });

    test('analysis streams zip when route files precede export xml', () async {
      const xml = '''
        <HealthData>
          <Workout workoutActivityType="HKWorkoutActivityTypeRunning" sourceName="Apple Watch"
            startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:30:00 +0000"
            duration="30" durationUnit="min">
            <WorkoutRoute sourceName="Apple Watch"
              startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:30:00 +0000">
              <FileReference path="/workout-routes/route_2026-01-01_8.00am.gpx" />
            </WorkoutRoute>
          </Workout>
        </HealthData>
      ''';
      final repository = FakeAppleHealthImportRepository();

      final result = await AppleHealthImportService(repository)
          .analyzeAppleHealthExport(zipExport(
        xml,
        extraFiles: {
          'apple_health_export/workout-routes/route_2026-01-01_8.00am.gpx':
              '<not-gpx>',
        },
        extraFilesBeforeXml: true,
      ));

      final workoutSummary = result.categorySummaries
          .firstWhere((it) => it.category == AppleHealthImportCategory.workouts);
      expect(result.parsedWorkouts, 1);
      expect(workoutSummary.convertedRecords, 1);
      expect(workoutSummary.routeSessions, 1);
      expect(repository.insertedBatches, isEmpty);
    });
  });
}
