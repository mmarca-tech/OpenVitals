import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_connect_native/health_connect_native.dart';
import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/domain/model/activity_models.dart';
import 'package:openvitals/domain/model/body_models.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/domain/model/nutrition_models.dart';
import 'package:openvitals/domain/model/vitals_models.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_records.dart';
import 'package:openvitals/health/native/health_connect_native_data_source.dart';
import 'package:openvitals/health/native/health_record_json.dart';

const _appPackage = 'tech.mmarca.openvitals';

/// In-memory [HealthConnectHostApi] that returns canned JSON and captures
/// writes/deletes, so the data source can be exercised without a device.
class FakeHostApi extends HealthConnectHostApi {
  FakeHostApi() : super();

  int sdkStatus = 3;
  Set<String> availableFeatures = {};
  List<String> grantedPermissionsResult = const [];
  bool requestPermissionsResult = true;

  final Map<String, List<String>> records = {};
  final Map<String, Map<String, String>> singleRecords = {};
  Map<String, double?> aggregateValues = {};
  List<String> periodBuckets = const [];
  List<String> existingClientIds = const [];

  final List<Map<String, dynamic>> inserted = [];
  final List<({String type, List<String> ids})> deletedByIds = [];
  final List<({String type, List<String> ids})> filterQueries = [];

  @override
  Future<int> getSdkStatus() async => sdkStatus;

  @override
  Future<List<String>> getGrantedPermissions(List<String> permissions) async =>
      grantedPermissionsResult;

  @override
  Future<bool> requestPermissions(List<String> permissions) async =>
      requestPermissionsResult;

  @override
  Future<bool> isFeatureAvailable(String feature) async =>
      availableFeatures.contains(feature);

  @override
  Future<List<String>> readRecordsJson(
    String recordType,
    int startEpochMs,
    int endEpochMs,
    String? filterJson,
  ) async =>
      records[recordType] ?? const [];

  @override
  Future<String?> readRecordJson(String recordType, String recordId) async =>
      singleRecords[recordType]?[recordId];

  @override
  Future<Map<String, double?>> aggregate(
    List<String> aggregateMetrics,
    int startEpochMs,
    int endEpochMs,
  ) async =>
      {for (final m in aggregateMetrics) m: aggregateValues[m]};

  @override
  Future<List<String>> aggregateGroupByPeriodJson(
    List<String> aggregateMetrics,
    int startEpochMs,
    int endEpochMs,
    String bucketType,
  ) async =>
      periodBuckets;

  @override
  Future<List<String>> insertRecordsJson(List<String> recordsJson) async {
    for (final json in recordsJson) {
      inserted.add(jsonDecode(json) as Map<String, dynamic>);
    }
    return [for (var i = 0; i < recordsJson.length; i++) 'inserted_$i'];
  }

  @override
  Future<void> deleteRecordsByIds(
    String recordType,
    List<String> recordIds,
  ) async {
    deletedByIds.add((type: recordType, ids: recordIds));
  }

  @override
  Future<List<String>> filterExistingClientIds(
    String recordType,
    List<String> clientRecordIds,
  ) async {
    filterQueries.add((type: recordType, ids: clientRecordIds));
    return existingClientIds;
  }

  // ── Body (Phase 1) typed fakes ────────────────────────────────────────────
  List<WeightEntryMsg> weightEntries = const [];
  BodyMeasurementWriteRequestMsg? bodyWriteRequest;

  @override
  Future<List<WeightEntryMsg>> readWeightEntries(
    int startEpochMs,
    int endEpochMs,
  ) async =>
      weightEntries;

  @override
  Future<String> writeBodyMeasurementEntry(
    BodyMeasurementWriteRequestMsg request,
  ) async {
    bodyWriteRequest = request;
    return 'openvitals_body_${request.type.name}_written';
  }

  // ── Hydration (Phase 2) typed fakes ───────────────────────────────────────
  HydrationWriteRequestMsg? hydrationWriteRequest;

  @override
  Future<String> writeHydrationEntry(HydrationWriteRequestMsg request) async {
    hydrationWriteRequest = request;
    return 'openvitals_hydration_written';
  }

  // ── Sleep (Phase 7) typed fakes ───────────────────────────────────────────
  final Map<String, SleepDataMsg> sleepById = {};

  @override
  Future<SleepDataMsg?> readSleepSessionById(String id) async => sleepById[id];

  // ── Heart (Phase 5) typed fakes ───────────────────────────────────────────
  List<HeartRateSampleMsg> rawHeartRateSamples = const [];

  @override
  Future<List<HeartRateSampleMsg>> readRawHeartRateSamples(
    int startEpochMs,
    int endEpochMs,
  ) async =>
      rawHeartRateSamples;

  // ── Vitals (Phase 3) typed fakes ──────────────────────────────────────────
  List<BloodPressureEntryMsg> bloodPressureEntries = const [];
  VitalsMeasurementWriteRequestMsg? vitalsWriteRequest;

  @override
  Future<List<BloodPressureEntryMsg>> readBloodPressureEntries(
    int startEpochMs,
    int endEpochMs,
  ) async =>
      bloodPressureEntries;

  @override
  Future<String> writeVitalsMeasurementEntry(
    VitalsMeasurementWriteRequestMsg request,
  ) async {
    vitalsWriteRequest = request;
    return 'openvitals_vitals_${request.type.name}_written';
  }

  // ── Nutrition (Phase 6) typed fakes ───────────────────────────────────────
  NutritionWriteRequestMsg? nutritionWriteRequest;

  @override
  Future<String> writeNutritionEntry(NutritionWriteRequestMsg request) async {
    nutritionWriteRequest = request;
    return 'openvitals_nutrition_written';
  }
}

HealthConnectNativeDataSource _source(FakeHostApi api) =>
    HealthConnectNativeDataSource(hostApi: api, appPackageName: _appPackage);

int _ms(int y, int mo, int d, [int h = 0, int mi = 0]) =>
    DateTime.utc(y, mo, d, h, mi).millisecondsSinceEpoch;

void main() {
  group('availability', () {
    test('maps SDK status ints and caches the result', () async {
      final api = FakeHostApi()..sdkStatus = 3;
      final source = _source(api);
      expect(await source.availability(), HealthConnectAvailability.available);
      expect(source.cachedAvailability, HealthConnectAvailability.available);

      api.sdkStatus = 2;
      expect(await source.availability(),
          HealthConnectAvailability.needsProviderUpdate);

      api.sdkStatus = 1;
      expect(await source.availability(), HealthConnectAvailability.notSupported);
    });

    test('resolveFeatureFlags reads optional-feature availability', () async {
      final api = FakeHostApi()
        ..availableFeatures = {'SKIN_TEMPERATURE', 'MINDFULNESS_SESSION'};
      final source = _source(api);
      final flags = await source.resolveFeatureFlags();
      expect(flags.skinTemperatureAvailable, isTrue);
      expect(flags.mindfulnessAvailable, isTrue);
      expect(flags.plannedExerciseAvailable, isFalse);
      expect(source.isSkinTemperatureAvailable(), isTrue);
    });
  });

  group('permissions', () {
    test('grantedPermissions returns the plugin-reported subset', () async {
      final api = FakeHostApi()
        ..grantedPermissionsResult = [
          'android.permission.health.READ_STEPS',
          'android.permission.health.READ_SLEEP',
        ];
      final source = _source(api);
      final granted = await source.grantedPermissions();
      expect(granted, {
        'android.permission.health.READ_STEPS',
        'android.permission.health.READ_SLEEP',
      });
    });

    test('requestPermissions returns false for an empty set', () async {
      final source = _source(FakeHostApi()..requestPermissionsResult = true);
      expect(await source.requestPermissions(const {}), isFalse);
      expect(
        await source.requestPermissions({'android.permission.health.READ_STEPS'}),
        isTrue,
      );
    });
  });

  group('reads', () {
    test('ExerciseSession JSON maps to ExerciseData with segments/laps/route',
        () async {
      final api = FakeHostApi();
      api.records['ExerciseSession'] = [
        jsonEncode({
          'recordType': 'ExerciseSession',
          'id': 'ex-1',
          'clientRecordId': 'openvitals_activity_1',
          'dataOriginPackage': _appPackage,
          'startEpochMs': _ms(2026, 1, 2, 8),
          'endEpochMs': _ms(2026, 1, 2, 9),
          'exerciseType': 56,
          'title': 'Morning run',
          'notes': 'felt good',
          'segments': [
            {
              'startEpochMs': _ms(2026, 1, 2, 8),
              'endEpochMs': _ms(2026, 1, 2, 8, 30),
              'segmentType': 42,
              'repetitions': 12,
            },
          ],
          'laps': [
            {
              'startEpochMs': _ms(2026, 1, 2, 8),
              'endEpochMs': _ms(2026, 1, 2, 8, 15),
              'lengthMeters': 1000.0,
            },
          ],
          'route': {
            'points': [
              {
                'timeEpochMs': _ms(2026, 1, 2, 8),
                'latitude': 51.5,
                'longitude': -0.12,
                'altitudeMeters': 10.0,
              },
            ],
          },
        }),
      ];
      final sessions = await _source(api).readExerciseSessions(
        DateTime.utc(2026, 1, 2),
        DateTime.utc(2026, 1, 3),
      );
      expect(sessions, hasLength(1));
      final session = sessions.single;
      expect(session.id, 'ex-1');
      expect(session.exerciseType, 56);
      expect(session.title, 'Morning run');
      expect(session.clientRecordId, 'openvitals_activity_1');
      expect(session.isOpenVitalsEntry, isTrue);
      expect(session.durationMs, 3600000);
      expect(session.segments, hasLength(1));
      expect(session.segments.single.segmentType, 42);
      expect(session.segments.single.repetitions, 12);
      expect(session.laps, hasLength(1));
      expect(session.laps.single.lengthMeters, 1000.0);
      expect(session.route.status, ExerciseRouteStatus.data);
      expect(session.route.points, hasLength(1));
      expect(session.route.points.single.latitude, 51.5);
    });

    test('HeartRate raw samples map from typed msgs (short range)', () async {
      // A 1h range is below the aggregate threshold, so the data source takes
      // the raw path; sample flattening now happens in the native reader.
      final api = FakeHostApi()
        ..rawHeartRateSamples = [
          HeartRateSampleMsg(
            timeEpochMs: _ms(2026, 1, 2, 6),
            beatsPerMinute: 60,
            source: 'com.watch',
          ),
          HeartRateSampleMsg(
            timeEpochMs: _ms(2026, 1, 2, 6, 5),
            beatsPerMinute: 80,
            source: 'com.watch',
          ),
        ];
      final samples = await _source(api).readHeartRateSamples(
        DateTime.utc(2026, 1, 2, 6),
        DateTime.utc(2026, 1, 2, 7),
      );
      expect(samples, hasLength(2));
      expect(samples.map((s) => s.beatsPerMinute), [60, 80]);
      expect(samples.every((s) => s.source == 'com.watch'), isTrue);
    });

    test('BloodPressure entries map systolic/diastolic and ownership',
        () async {
      final api = FakeHostApi()
        ..bloodPressureEntries = [
          BloodPressureEntryMsg(
            timeEpochMs: _ms(2026, 1, 2, 8),
            systolicMmHg: 120,
            diastolicMmHg: 80,
            source: _appPackage,
            id: 'bp-1',
            isOpenVitalsEntry: true,
          ),
        ];
      final entries = await _source(api).readBloodPressureEntries(
        DateTime.utc(2026, 1, 2),
        DateTime.utc(2026, 1, 3),
      );
      expect(entries.single.systolicMmHg, 120);
      expect(entries.single.diastolicMmHg, 80);
      expect(entries.single.isOpenVitalsEntry, isTrue);
    });

    test('readSteps / readDistanceMeters use the aggregate API', () async {
      final api = FakeHostApi()
        ..aggregateValues = {
          'Steps.count': 8421.0,
          'Distance.distance': 6123.4,
          'FloorsClimbed.floors': 12.0,
        };
      final source = _source(api);
      final date = LocalDate(2026, 1, 2);
      expect(await source.readSteps(date), 8421);
      expect(await source.readDistanceMeters(date), closeTo(6123.4, 1e-9));
      expect(await source.readFloorsClimbed(date), 12);
    });

    test('readDailySteps maps aggregate period buckets per day', () async {
      final api = FakeHostApi();
      final dayStartMs = DateTime(2026, 1, 2).millisecondsSinceEpoch;
      api.periodBuckets = [
        jsonEncode({
          'startEpochMs': dayStartMs,
          'endEpochMs': DateTime(2026, 1, 3).millisecondsSinceEpoch,
          'values': {
            'Steps.count': 5000.0,
            'Distance.distance': 4000.0,
            'ActiveCaloriesBurned.energy': 220.0,
          },
        }),
      ];
      final daily = await _source(api).readDailySteps(
        LocalDate(2026, 1, 2),
        LocalDate(2026, 1, 2),
        includeActiveCalories: true,
      );
      expect(daily, hasLength(1));
      expect(daily.single.date, LocalDate(2026, 1, 2));
      expect(daily.single.steps, 5000);
      expect(daily.single.distanceMeters, 4000.0);
      expect(daily.single.activeCaloriesKcal, 220.0);
    });

    test('single Sleep session maps stages from a typed msg', () async {
      final api = FakeHostApi()
        ..sleepById['sleep-1'] = SleepDataMsg(
          id: 'sleep-1',
          startEpochMs: _ms(2026, 1, 2, 23),
          endEpochMs: _ms(2026, 1, 3, 6),
          source: 'com.watch',
          title: 'Night',
          notes: null,
          clientRecordId: null,
          device: null,
          stages: [
            SleepStageMsg(
              startEpochMs: _ms(2026, 1, 2, 23),
              endEpochMs: _ms(2026, 1, 3, 1),
              stageType: 4,
            ),
            SleepStageMsg(
              startEpochMs: _ms(2026, 1, 3, 1),
              endEpochMs: _ms(2026, 1, 3, 6),
              stageType: 5,
            ),
          ],
        );
      final session = await _source(api).readSleepSession('sleep-1');
      expect(session, isNotNull);
      expect(session!.id, 'sleep-1');
      expect(session.stages, hasLength(2));
      expect(session.stages.first.stageType, 4);
      expect(session.stages.last.stageType, 5);
    });

    test('Weight entries map from typed msgs and preserve ownership', () async {
      // Unit conversion + ownership tagging now happen in the native
      // BodyHealthReader; the data source maps WeightEntryMsg -> WeightEntry.
      final api = FakeHostApi()
        ..weightEntries = [
          WeightEntryMsg(
            timeEpochMs: _ms(2026, 1, 1, 8),
            weightKg: 79.0,
            source: 'com.other',
            id: 'w-2',
            isOpenVitalsEntry: false,
          ),
          WeightEntryMsg(
            timeEpochMs: _ms(2026, 1, 2, 8),
            weightKg: 80.5,
            source: _appPackage,
            id: 'w-1',
            isOpenVitalsEntry: true,
          ),
        ];
      final entries = await _source(api).readWeightEntries(
        LocalDate(2026, 1, 1),
        LocalDate(2026, 1, 2),
      );
      expect(entries.map((e) => e.weightKg), [79.0, 80.5]);
      expect(entries.last.isOpenVitalsEntry, isTrue);
      expect(entries.first.isOpenVitalsEntry, isFalse);
      expect(entries.first.source, 'com.other');
    });

    test('Height record reports centimetres from metres', () async {
      final map = <String, dynamic>{
        'recordType': 'Height',
        'id': 'h-1',
        'dataOriginPackage': 'com.other',
        'timeEpochMs': _ms(2026, 1, 2, 8),
        'heightMeters': 1.83,
      };
      final entry = HealthRecordJson.heightEntry(map, _appPackage);
      expect(entry.heightCm, closeTo(183.0, 1e-9));
    });
  });

  group('writes', () {
    test('writeHydrationEntry forwards a typed request', () async {
      // The record build (litres->mL, clientRecordId) now lives in the native
      // HydrationHealthReader; the data source forwards the typed request.
      final api = FakeHostApi();
      final id = await _source(api).writeHydrationEntry(
        HydrationWriteRequest(
          time: DateTime.utc(2026, 1, 2, 10),
          volumeLiters: 0.25,
        ),
      );
      expect(id, startsWith('openvitals_hydration_'));
      final req = api.hydrationWriteRequest!;
      expect(req.volumeLiters, 0.25);
      expect(req.timeEpochMs, _ms(2026, 1, 2, 10));
    });

    test('writeBodyMeasurementEntry forwards a typed request', () async {
      // The cm->m conversion + record build now live in the native
      // BodyHealthReader; the data source forwards the typed request.
      final api = FakeHostApi();
      final id = await _source(api).writeBodyMeasurementEntry(
        BodyMeasurementWriteRequest(
          type: BodyMeasurementType.height,
          time: DateTime.utc(2026, 1, 2, 8),
          value: 183.0,
        ),
      );
      expect(id, startsWith('openvitals_body_height_'));
      final req = api.bodyWriteRequest!;
      expect(req.type, BodyMeasurementTypeMsg.height);
      expect(req.value, 183.0);
      expect(req.timeEpochMs, _ms(2026, 1, 2, 8));
    });

    test('writeVitalsMeasurementEntry forwards a typed request', () async {
      // The record build (mmHg units, clientRecordId) now lives in the native
      // VitalsHealthReader; the data source forwards the typed request.
      final api = FakeHostApi();
      final id = await _source(api).writeVitalsMeasurementEntry(
        VitalsMeasurementWriteRequest(
          type: VitalsMeasurementType.bloodPressure,
          time: DateTime.utc(2026, 1, 2, 8),
          value: 118,
          secondaryValue: 76,
        ),
      );
      expect(id, isNotEmpty);
      final req = api.vitalsWriteRequest!;
      expect(req.type, VitalsMeasurementTypeMsg.bloodPressure);
      expect(req.value, 118);
      expect(req.secondaryValue, 76);
      expect(req.timeEpochMs, _ms(2026, 1, 2, 8));
    });

    test('writeNutritionEntry forwards a typed request keyed by storageName',
        () async {
      // The NutritionRecord field mapping now lives in the native reader; the
      // data source forwards nutrient values keyed by NutritionNutrient.storageName.
      final api = FakeHostApi();
      await _source(api).writeNutritionEntry(
        NutritionWriteRequest(
          time: DateTime.utc(2026, 1, 2, 12),
          name: 'Lunch',
          nutrientValues: {
            NutritionNutrient.energy: 500.0,
            NutritionNutrient.protein: 30.0,
            NutritionNutrient.totalCarbohydrate: 60.0,
            NutritionNutrient.dietaryFiber: 8.0,
            NutritionNutrient.caffeine: 0.05,
          },
        ),
      );
      final req = api.nutritionWriteRequest!;
      expect(req.name, 'Lunch');
      expect(req.timeEpochMs, _ms(2026, 1, 2, 12));
      expect(req.nutrientValues['ENERGY'], 500.0);
      expect(req.nutrientValues['PROTEIN'], 30.0);
      expect(req.nutrientValues['TOTAL_CARBOHYDRATE'], 60.0);
      expect(req.nutrientValues['DIETARY_FIBER'], 8.0);
      expect(req.nutrientValues['CAFFEINE'], 0.05);
    });

    test('writeActivityEntry builds an ExerciseSession with the HC type + segments',
        () async {
      final api = FakeHostApi();
      final id = await _source(api).writeActivityEntry(
        ActivityWriteRequest(
          exerciseType: 56,
          startTime: DateTime.utc(2026, 1, 2, 8),
          endTime: DateTime.utc(2026, 1, 2, 9),
          title: 'Run',
          exerciseSegments: [
            ActivityExerciseSegmentWrite(
              startTime: DateTime.utc(2026, 1, 2, 8),
              endTime: DateTime.utc(2026, 1, 2, 8, 30),
              segmentType: 42,
              repetitions: 10,
            ),
          ],
        ),
      );
      expect(id, startsWith('openvitals_activity_'));
      final record = api.inserted.single;
      expect(record['recordType'], 'ExerciseSession');
      expect(record['exerciseType'], 56);
      expect(record['title'], 'Run');
      expect((record['segments'] as List), hasLength(1));
      expect((record['segments'] as List).first['repetitions'], 10);
    });

    test('deleteActivityEntry deletes the ExerciseSession by id', () async {
      final api = FakeHostApi();
      await _source(api).deleteActivityEntry('ex-9');
      expect(api.deletedByIds.single.type, 'ExerciseSession');
      expect(api.deletedByIds.single.ids, ['ex-9']);
    });
  });

  group('apple health import', () {
    test('insertImportedRecords converts every record to canonical JSON',
        () async {
      final api = FakeHostApi();
      await _source(api).insertImportedRecords([
        WeightImportRecord(
          clientRecordId: 'apple_health_weight_1',
          time: DateTime.utc(2026, 1, 2, 8),
          zoneOffset: null,
          kilograms: 81.2,
        ),
        SleepSessionImportRecord(
          clientRecordId: 'apple_health_sleep_1',
          startTime: DateTime.utc(2026, 1, 2, 23),
          startZoneOffset: null,
          endTime: DateTime.utc(2026, 1, 3, 6),
          endZoneOffset: null,
          title: 'Night',
          stages: [
            SleepStageValue(
              startTime: DateTime.utc(2026, 1, 2, 23),
              endTime: DateTime.utc(2026, 1, 3, 6),
              stage: SleepStageType.deep,
            ),
          ],
        ),
      ]);
      expect(api.inserted, hasLength(2));
      final weight = api.inserted[0];
      expect(weight['recordType'], 'Weight');
      expect(weight['weightKg'], 81.2);
      expect(weight['clientRecordId'], 'apple_health_weight_1');
      final sleep = api.inserted[1];
      expect(sleep['recordType'], 'Sleep');
      expect((sleep['stages'] as List).single['stage'], 5); // DEEP
      expect(sleep['clientRecordId'], 'apple_health_sleep_1');
    });

    test('findMatchingImportedClientRecordIds maps targetType and filters',
        () async {
      final api = FakeHostApi()..existingClientIds = ['apple_health_a'];
      final matched = await _source(api).findMatchingImportedClientRecordIds(
        'SleepSessionRecord',
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 1, 3),
        {'apple_health_a', 'apple_health_b'},
      );
      expect(matched, {'apple_health_a'});
      // SleepSessionRecord maps to the schema record type "Sleep".
      expect(api.filterQueries.single.type, 'Sleep');
    });
  });
}
