import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/data/repository/contract/apple_health_import_repository.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_checkpoint_store.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_models.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_records.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_service.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_xml_support.dart';

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

/// The importer only ever reads a *staged file*, never a `List<int>`, so every
/// fixture is written to a temp file first.
late Directory exportDirectory;
var _exportFileIndex = 0;

File exportFile(List<int> bytes) {
  final file = File('${exportDirectory.path}/export-${_exportFileIndex++}.bin');
  file.writeAsBytesSync(bytes);
  return file;
}


/// The byte offset of `name`'s local file header inside [zip], its compressed
/// payload offset, and that payload's length — enough to cut the archive at a
/// precise point *inside* a specific entry.
({int dataOffset, int compressedSize}) entryData(List<int> zip, String name) {
  final nameBytes = utf8.encode(name);
  for (var index = 0; index + 30 + nameBytes.length <= zip.length; index++) {
    if (zip[index] != 0x50 ||
        zip[index + 1] != 0x4B ||
        zip[index + 2] != 0x03 ||
        zip[index + 3] != 0x04) {
      continue;
    }
    final nameLength = zip[index + 26] | (zip[index + 27] << 8);
    final extraLength = zip[index + 28] | (zip[index + 29] << 8);
    if (nameLength != nameBytes.length) continue;
    var matches = true;
    for (var offset = 0; offset < nameLength; offset++) {
      if (zip[index + 30 + offset] != nameBytes[offset]) {
        matches = false;
        break;
      }
    }
    if (!matches) continue;
    final compressedSize = zip[index + 18] |
        (zip[index + 19] << 8) |
        (zip[index + 20] << 16) |
        (zip[index + 21] << 24);
    return (
      dataOffset: index + 30 + nameLength + extraLength,
      compressedSize: compressedSize,
    );
  }
  throw StateError('No local file header for $name');
}

/// A ZIP cut in half *inside* the payload of [entryName] — the end-of-central
/// directory record is gone, so only a sequential reader can salvage anything.
List<int> truncatedInside(List<int> zip, String entryName) {
  final entry = entryData(zip, entryName);
  expect(entry.compressedSize, greaterThan(4));
  return zip.sublist(0, entry.dataOffset + (entry.compressedSize ~/ 2));
}

String routeGpx(int points) {
  final buffer = StringBuffer(
    '<gpx><trk><trkseg>',
  );
  for (var index = 0; index < points; index++) {
    final lat = 45.0 + index * 0.0001;
    final lon = 9.0 + index * 0.0001;
    buffer.write('<trkpt lat="$lat" lon="$lon"><ele>${100 + index}</ele></trkpt>');
  }
  buffer.write('</trkseg></trk></gpx>');
  return buffer.toString();
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
    setUp(() {
      exportDirectory =
          Directory.systemTemp.createTempSync('apple_health_service_test');
    });

    tearDown(() {
      if (exportDirectory.existsSync()) {
        exportDirectory.deleteSync(recursive: true);
      }
    });

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
          .importAppleHealthExport(exportFile(utf8.encode(xml)),
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
          .analyzeAppleHealthExport(exportFile(utf8.encode(xml)));

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
          .analyzeAppleHealthExport(exportFile(zipExport(
        xml,
        extraFiles: {
          'apple_health_export/workout-routes/route_2026-01-01_8.00am.gpx':
              '<not-gpx>',
        },
      )));

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
        exportFile(utf8.encode(xml)),
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
          .importAppleHealthExport(exportFile(utf8.encode(buffer.toString())));

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
        exportFile(utf8.encode(heartRateExport(700))),
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
        exportFile(utf8.encode(heartRateExport(400, duplicateIndexOf: (350, 0)))),
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
          .importAppleHealthExport(exportFile(utf8.encode(xml)));

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
          .analyzeAppleHealthExport(exportFile(zipExport(
        xml,
        extraFiles: {
          'apple_health_export/workout-routes/route_2026-01-01_8.00am.gpx':
              '<not-gpx>',
        },
        extraFilesBeforeXml: true,
      )));

      final workoutSummary = result.categorySummaries
          .firstWhere((it) => it.category == AppleHealthImportCategory.workouts);
      expect(result.parsedWorkouts, 1);
      expect(workoutSummary.convertedRecords, 1);
      expect(workoutSummary.routeSessions, 1);
      expect(repository.insertedBatches, isEmpty);
    });
    test(
        'a ZIP truncated inside a workout-route entry still imports the health '
        'records and flags workoutRoutesIncomplete', () async {
      const xml = '''
        <HealthData>
          <Record type="HKQuantityTypeIdentifierHeartRate" sourceName="Watch"
            startDate="2026-01-01 08:00:00 +0000" endDate="2026-01-01 08:00:00 +0000"
            unit="count/min" value="62" />
          <Record type="HKQuantityTypeIdentifierBodyMass" sourceName="Scale"
            startDate="2026-01-01 07:00:00 +0000" endDate="2026-01-01 07:00:00 +0000"
            unit="kg" value="70" />
          <Workout workoutActivityType="HKWorkoutActivityTypeRunning" sourceName="Watch"
            startDate="2026-01-01 09:00:00 +0000" endDate="2026-01-01 09:30:00 +0000"
            duration="30" durationUnit="min">
            <WorkoutRoute sourceName="Watch">
              <FileReference path="/workout-routes/route1.gpx" />
            </WorkoutRoute>
          </Workout>
        </HealthData>
      ''';
      final zip = zipExport(
        xml,
        extraFiles: {
          'apple_health_export/workout-routes/route1.gpx': routeGpx(80),
          'apple_health_export/workout-routes/route2.gpx': routeGpx(80),
        },
      );
      final repository = FakeAppleHealthImportRepository();

      final result = await AppleHealthImportService(repository)
          .importAppleHealthExport(
        exportFile(truncatedInside(
          zip,
          'apple_health_export/workout-routes/route1.gpx',
        )),
      );

      // export.xml was intact, so everything it described still imports.
      expect(result.parsedRecords, 2);
      expect(result.parsedWorkouts, 1);
      expect(result.importedRecords, greaterThanOrEqualTo(3));
      expect(result.workoutRoutesIncomplete, isTrue);

      final report = result.shareableReportText;
      expect(report, contains('Workout routes incomplete: true'));
      expect(report, contains('Activities Requiring Manual Route Import'));
      expect(report, contains('workout-routes/route1.gpx'));
      expect(report, contains('route_archive_truncated'));
      expect(
        result.diagnostics.map((it) => it.reasonCode),
        containsAll(<String>['route_archive_truncated', 'workout_route_unavailable']),
      );
    });

    test('a ZIP truncated before export.xml is read still hard-fails', () async {
      final zip = zipExport(
        heartRateExport(200),
        extraFiles: {
          'apple_health_export/workout-routes/route1.gpx': routeGpx(80),
        },
      );
      final repository = FakeAppleHealthImportRepository();

      await expectLater(
        AppleHealthImportService(repository).importAppleHealthExport(
          exportFile(truncatedInside(zip, 'apple_health_export/export.xml')),
        ),
        throwsA(isA<AppleHealthZipReadException>()),
      );
      expect(repository.insertedBatches, isEmpty);
    });

    test('an unreadable route is not reported when workouts are deselected',
        () async {
      const xml = '''
        <HealthData>
          <Record type="HKQuantityTypeIdentifierBodyMass" sourceName="Scale"
            startDate="2026-01-01 07:00:00 +0000" endDate="2026-01-01 07:00:00 +0000"
            unit="kg" value="70" />
          <Workout workoutActivityType="HKWorkoutActivityTypeRunning" sourceName="Watch"
            startDate="2026-01-01 09:00:00 +0000" endDate="2026-01-01 09:30:00 +0000"
            duration="30" durationUnit="min">
            <WorkoutRoute sourceName="Watch">
              <FileReference path="/workout-routes/route1.gpx" />
            </WorkoutRoute>
          </Workout>
        </HealthData>
      ''';
      final zip = zipExport(
        xml,
        extraFiles: {
          'apple_health_export/workout-routes/route1.gpx': routeGpx(80),
        },
      );
      final repository = FakeAppleHealthImportRepository();

      final result = await AppleHealthImportService(repository)
          .importAppleHealthExport(
        exportFile(truncatedInside(
          zip,
          'apple_health_export/workout-routes/route1.gpx',
        )),
        selectedCategories: {AppleHealthImportCategory.body},
      );

      // Route entries were never read (Kotlin a852d4e), so nothing is damaged.
      expect(result.workoutRoutesIncomplete, isFalse);
      expect(
        result.diagnostics.map((it) => it.reasonCode),
        isNot(contains('workout_route_unavailable')),
      );
      expect(result.importedRecords, 1);
    });

    test('saves a checkpoint after every batch and resumes without rewriting '
        'committed records', () async {
      final xml = heartRateExport(700);
      final file = exportFile(utf8.encode(xml));
      const sourceKey = 'content://downloads/1|export.xml|700';
      const selected = {AppleHealthImportCategory.heart};

      final firstRepository = FakeAppleHealthImportRepository();
      final checkpoints = <AppleHealthImportCheckpoint>[];
      final result = await AppleHealthImportService(firstRepository)
          .importAppleHealthExport(
        file,
        selectedCategories: selected,
        resumeCheckpoint: const AppleHealthImportCheckpoint(
          sourceKey: sourceKey,
          selectedCategories: selected,
        ),
        onCheckpoint: checkpoints.add,
      );

      expect(result.importedRecords, 700);
      expect(firstRepository.insertedRecords.length, 700);
      // 700 records / 300-record batches → a checkpoint after each of 3 writes.
      expect(
        checkpoints.map((it) => it.committedSelectedRecords),
        [300, 600, 700],
      );
      expect(checkpoints.last.importedRecords, 700);

      // The process dies after the first batch: resume from that checkpoint.
      final resumeFrom = checkpoints.first;
      final resumedRepository = FakeAppleHealthImportRepository();
      final resumed = await AppleHealthImportService(resumedRepository)
          .importAppleHealthExport(
        file,
        selectedCategories: selected,
        resumeCheckpoint: resumeFrom,
      );

      // The 300 already-committed records are not written again...
      expect(resumedRepository.insertedRecords.length, 400);
      // ...but the totals still describe the whole export.
      expect(resumed.importedRecords, 700);
      expect(
        resumed.typeSummaries
            .firstWhere((it) => it.appleType.contains('HeartRate'))
            .imported,
        700,
      );
    });

    test('a checkpoint that skips everything writes nothing at all', () async {
      final repository = FakeAppleHealthImportRepository();
      final result = await AppleHealthImportService(repository)
          .importAppleHealthExport(
        exportFile(utf8.encode(heartRateExport(400))),
        selectedCategories: const {AppleHealthImportCategory.heart},
        resumeCheckpoint: const AppleHealthImportCheckpoint(
          sourceKey: 'k',
          selectedCategories: {AppleHealthImportCategory.heart},
          committedSelectedRecords: 400,
          importedRecords: 400,
        ),
      );

      expect(repository.insertedBatches, isEmpty);
      expect(result.importedRecords, 400);
    });
  });
}
