import 'dart:convert';
import 'dart:math' as math;

import 'package:health_connect_native/health_connect_native.dart';

import '../../core/time/local_date.dart';
import '../../domain/model/activity_models.dart';
import '../../domain/model/activity_session_deduplication.dart';
import '../../domain/model/body_models.dart';
import '../../domain/model/cycle_models.dart';
import '../../domain/model/health_connect_availability.dart';
import '../../domain/model/heart_models.dart';
import '../../domain/model/mindfulness_models.dart';
import '../../domain/model/nutrition_models.dart';
import '../../domain/model/sleep_models.dart';
import '../../domain/model/sleep_session_merging.dart';
import '../../domain/model/vitals_models.dart';
import '../../domain/preferences/sleep_range_mode.dart';
import '../../features/imports/applehealth/apple_health_import_records.dart';
import '../health_data_source.dart';
import '../health_permissions.dart';
import 'health_record_json.dart';

/// Real [HealthDataSource] over the native AndroidX Health Connect plugin
/// ([HealthConnectHostApi]).
///
/// Records cross the bridge as JSON strings (canonical schema in
/// `packages/health_connect_native`); this source `jsonDecode`s them and maps
/// through [HealthRecordJson]. Daily activity totals are read via the Health
/// Connect aggregation API; individual entries via `readRecordsJson`.
///
/// Every read is defensive (per-metric degrade to empty/null), mirroring the
/// Kotlin readers which swallow Health Connect failures per metric. Reads the
/// old `health`-package impl left unimplemented (base empty defaults) stay that
/// way here for parity; the two genuine gains the native bridge unlocks —
/// `clientRecordId` round-tripping and full Apple-Health import coverage — are
/// implemented (see [insertImportedRecords] / [findMatchingImportedClientRecordIds]).
class HealthConnectNativeDataSource extends HealthDataSource {
  HealthConnectNativeDataSource({
    HealthConnectHostApi? hostApi,
    super.appPackageName,
  }) : _api = hostApi ?? HealthConnectHostApi();

  final HealthConnectHostApi _api;
  final math.Random _random = math.Random();

  // ── Time helpers (device-local day boundaries, as in the Kotlin readers) ──
  DateTime _dayStart(LocalDate date) => DateTime(date.year, date.month, date.day);
  DateTime _dayEnd(LocalDate date) => _dayStart(date.plusDays(1));

  /// Maps a Pigeon epoch-millis field back to a local [DateTime].
  DateTime _fromMs(int epochMs) => DateTime.fromMillisecondsSinceEpoch(epochMs);

  Future<T> _catch<T>(Future<T> Function() block, T fallback) async {
    try {
      return await block();
    } catch (_) {
      return fallback;
    }
  }

  String _newId() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(1 << 32).toRadixString(16);
    return '${millis}_$rand';
  }

  Future<List<Map<String, dynamic>>> _read(
    String recordType,
    DateTime start,
    DateTime end,
  ) async {
    final raw = await _catch(
      () => _api.readRecordsJson(
        recordType,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        null,
      ),
      const <String>[],
    );
    return [
      for (final json in raw) jsonDecode(json) as Map<String, dynamic>,
    ];
  }

  Future<Map<String, dynamic>?> _readOne(String recordType, String id) async {
    final json = await _catch(
      () => _api.readRecordJson(recordType, id),
      null,
    );
    return json == null ? null : jsonDecode(json) as Map<String, dynamic>;
  }

  Future<Map<String, double?>> _aggregate(
    List<String> metrics,
    DateTime start,
    DateTime end,
  ) =>
      _catch(
        () => _api.aggregate(
          metrics,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ),
        <String, double?>{for (final m in metrics) m: null},
      );

  // ── Availability / permissions ────────────────────────────────────────────

  @override
  Future<HealthConnectAvailability> availability() async {
    // HealthConnectClient SDK status: SDK_UNAVAILABLE=1,
    // SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED=2, SDK_AVAILABLE=3.
    final status = await _catch(() => _api.getSdkStatus(), 1);
    final resolved = switch (status) {
      3 => HealthConnectAvailability.available,
      2 => HealthConnectAvailability.needsProviderUpdate,
      _ => HealthConnectAvailability.notSupported,
    };
    cachedAvailability = resolved;
    return resolved;
  }

  @override
  Future<HealthConnectFeatureFlags> resolveFeatureFlags() async {
    Future<bool> feature(String name) =>
        _catch(() => _api.isFeatureAvailable(name), false);
    // Resolve the feature checks concurrently rather than sequentially so
    // onboarding startup does one round-trip's worth of latency, not five.
    final results = await Future.wait(<Future<bool>>[
      feature('SKIN_TEMPERATURE'),
      feature('MINDFULNESS_SESSION'),
      feature('PLANNED_EXERCISE'),
      feature('READ_HEALTH_DATA_HISTORY'),
      feature('READ_HEALTH_DATA_IN_BACKGROUND'),
    ]);
    final flags = HealthConnectFeatureFlags(
      skinTemperatureAvailable: results[0],
      mindfulnessAvailable: results[1],
      plannedExerciseAvailable: results[2],
      healthDataHistoryAvailable: results[3],
      backgroundReadAvailable: results[4],
    );
    featureFlags = flags;
    return flags;
  }

  @override
  Future<bool> requestPermissions(Set<String> permissions) async {
    if (permissions.isEmpty) return false;
    return _catch(
      () => _api.requestPermissions(permissions.toList()),
      false,
    );
  }

  @override
  Future<bool> openHealthConnectSettings() =>
      _catch(() => _api.openHealthConnectSettings(), false);

  @override
  Future<Set<String>> grantedPermissions() async {
    final managed = permissionService.managedPermissions.toList();
    if (managed.isEmpty) return const <String>{};
    final granted = await _catch(
      () => _api.getGrantedPermissions(managed),
      const <String>[],
    );
    return granted.toSet();
  }

  // ── Activity ──────────────────────────────────────────────────────────────

  @override
  Future<int> readSteps(LocalDate date) async {
    final agg = await _aggregate(
      const ['Steps.count'],
      _dayStart(date),
      _dayEnd(date),
    );
    return (agg['Steps.count'] ?? 0).round();
  }

  @override
  Future<double> readDistanceMeters(LocalDate date) async {
    final agg = await _aggregate(
      const ['Distance.distance'],
      _dayStart(date),
      _dayEnd(date),
    );
    return agg['Distance.distance'] ?? 0.0;
  }

  @override
  Future<int> readFloorsClimbed(LocalDate date) async {
    final agg = await _aggregate(
      const ['FloorsClimbed.floors'],
      _dayStart(date),
      _dayEnd(date),
    );
    return (agg['FloorsClimbed.floors'] ?? 0).round();
  }

  @override
  Future<List<DailySteps>> readDailySteps(
    LocalDate startDate,
    LocalDate endDate, {
    bool includeActiveCalories = false,
  }) async {
    final metrics = <String>[
      'Steps.count',
      'Distance.distance',
      if (includeActiveCalories) 'ActiveCaloriesBurned.energy',
    ];
    final buckets = await _catch(
      () => _api.aggregateGroupByPeriodJson(
        metrics,
        _dayStart(startDate).millisecondsSinceEpoch,
        _dayEnd(endDate).millisecondsSinceEpoch,
        'DAYS',
      ),
      const <String>[],
    );
    final byDate = <LocalDate, Map<String, double?>>{};
    for (final bucket in buckets) {
      final map = jsonDecode(bucket) as Map<String, dynamic>;
      final startMs = (map['startEpochMs'] as num).toInt();
      final date = LocalDate.fromDateTime(
        DateTime.fromMillisecondsSinceEpoch(startMs),
      );
      final values = (map['values'] as Map).cast<String, dynamic>();
      byDate[date] = {
        for (final entry in values.entries)
          entry.key: (entry.value as num?)?.toDouble(),
      };
    }
    final result = <DailySteps>[];
    var date = startDate;
    while (!date.isAfter(endDate)) {
      final values = byDate[date];
      result.add(
        DailySteps(
          date: date,
          steps: (values?['Steps.count'] ?? 0).round(),
          distanceMeters: values?['Distance.distance'] ?? 0.0,
          activeCaloriesKcal: includeActiveCalories
              ? (values?['ActiveCaloriesBurned.energy'])
              : null,
        ),
      );
      date = date.plusDays(1);
    }
    return result;
  }

  @override
  Future<List<ExerciseData>> readExerciseSessions(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('ExerciseSession', start, end);
    final sessions = [
      for (final m in maps) HealthRecordJson.exercise(m, appPackageName),
    ];
    return deduplicateExerciseSessions(sessions);
  }

  @override
  Future<ExerciseData?> readExerciseSession(String id) async {
    final map = await _readOne('ExerciseSession', id);
    return map == null ? null : HealthRecordJson.exercise(map, appPackageName);
  }

  @override
  Future<CaloriesBurnedValue?> readCaloriesBurned(
    LocalDate date, {
    bool includeEstimatedCalories = false,
  }) async {
    final agg = await _aggregate(
      const ['TotalCaloriesBurned.energy'],
      _dayStart(date),
      _dayEnd(date),
    );
    final kcal = agg['TotalCaloriesBurned.energy'];
    if (kcal == null || kcal <= 0) return null;
    return CaloriesBurnedValue(
      kcal: kcal,
      source: CaloriesBurnedSource.recordedTotal,
    );
  }

  @override
  Future<List<SpeedSample>> readSpeedSamples(DateTime start, DateTime end) async {
    final maps = await _read('Speed', start, end);
    return [
      for (final m in maps) ...HealthRecordJson.speedSamples(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  // ── Nutrition / hydration ─────────────────────────────────────────────────

  @override
  Future<double?> readCaloriesInKcal(LocalDate date) async {
    final agg = await _aggregate(
      const ['Nutrition.energy'],
      _dayStart(date),
      _dayEnd(date),
    );
    final kcal = agg['Nutrition.energy'];
    return (kcal != null && kcal > 0) ? kcal : null;
  }

  @override
  Future<List<NutritionEntry>> readNutritionEntries(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('Nutrition', start, end);
    return [
      for (final m in maps) HealthRecordJson.nutritionEntry(m, appPackageName),
    ];
  }

  @override
  Future<List<DailyMacros>> readDailyMacros(
    LocalDate startDate,
    LocalDate endDate,
  ) async {
    final entries =
        await readNutritionEntries(_dayStart(startDate), _dayEnd(endDate));
    final byDate = <LocalDate, Map<NutritionNutrient, double>>{};
    for (final entry in entries) {
      final date = LocalDate.fromDateTime(entry.time.toLocal());
      final bucket = byDate.putIfAbsent(date, () => <NutritionNutrient, double>{});
      entry.nutrientValues.forEach((nutrient, value) {
        bucket[nutrient] = (bucket[nutrient] ?? 0) + value;
      });
    }
    final dates = byDate.keys.toList()..sort();
    return [
      for (final date in dates)
        DailyMacros(date: date, nutrientValues: byDate[date]!),
    ];
  }

  // ── Hydration (Phase 2) — typed via native HydrationHealthReader ────────────

  HydrationEntry _hydrationEntry(HydrationEntryMsg m) => HydrationEntry(
        startTime: _fromMs(m.startEpochMs),
        endTime: _fromMs(m.endEpochMs),
        liters: m.liters,
        source: m.source,
        id: m.id,
        clientRecordId: m.clientRecordId,
        isOpenVitalsEntry: m.isOpenVitalsEntry,
      );

  @override
  Future<double?> readHydrationLiters(LocalDate date) => _catch(
        () => _api.readHydrationLiters(
          _dayStart(date).millisecondsSinceEpoch,
          _dayEnd(date).millisecondsSinceEpoch,
        ),
        null,
      );

  @override
  Future<List<DailyHydration>> readDailyHydration(
    LocalDate startDate,
    LocalDate endDate,
  ) async {
    final msgs = await _catch(
      () => _api.readDailyHydration(
        _dayStart(startDate).millisecondsSinceEpoch,
        _dayEnd(endDate).millisecondsSinceEpoch,
      ),
      const <DailyHydrationMsg>[],
    );
    // Native returns raw per-day aggregate buckets; fill the full range here so
    // days without hydration data still appear as 0 L (matches the reference).
    final byDay = <int, double>{
      for (final m in msgs)
        LocalDate.fromDateTime(_fromMs(m.dateEpochMs)).epochDay: m.liters,
    };
    final out = <DailyHydration>[];
    for (var date = startDate;
        date.compareTo(endDate) <= 0;
        date = date.plusDays(1)) {
      out.add(DailyHydration(date: date, liters: byDay[date.epochDay] ?? 0.0));
    }
    return out;
  }

  @override
  Future<List<HydrationEntry>> readHydrationEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readHydrationEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <HydrationEntryMsg>[],
    );
    return [for (final m in msgs) _hydrationEntry(m)];
  }

  @override
  Future<HydrationEntry?> readHydrationEntry(String id) async {
    final m = await _catch(() => _api.readHydrationEntry(id), null);
    return m == null ? null : _hydrationEntry(m);
  }

  // ── Body (Phase 1) — typed via native BodyHealthReader ──────────────────────

  BodyMeasurementTypeMsg _bodyTypeMsg(BodyMeasurementType type) => switch (type) {
        BodyMeasurementType.weight => BodyMeasurementTypeMsg.weight,
        BodyMeasurementType.height => BodyMeasurementTypeMsg.height,
        BodyMeasurementType.bodyFat => BodyMeasurementTypeMsg.bodyFat,
      };

  BodyMeasurementType _bodyType(BodyMeasurementTypeMsg type) => switch (type) {
        BodyMeasurementTypeMsg.weight => BodyMeasurementType.weight,
        BodyMeasurementTypeMsg.height => BodyMeasurementType.height,
        BodyMeasurementTypeMsg.bodyFat => BodyMeasurementType.bodyFat,
      };

  WeightEntry _weightEntry(WeightEntryMsg m) => WeightEntry(
        time: _fromMs(m.timeEpochMs),
        weightKg: m.weightKg,
        source: m.source,
        id: m.id,
        isOpenVitalsEntry: m.isOpenVitalsEntry,
      );

  HeightEntry _heightEntry(HeightEntryMsg m) => HeightEntry(
        time: _fromMs(m.timeEpochMs),
        heightCm: m.heightCm,
        source: m.source,
        id: m.id,
        isOpenVitalsEntry: m.isOpenVitalsEntry,
      );

  BodyFatEntry _bodyFatEntry(BodyFatEntryMsg m) => BodyFatEntry(
        time: _fromMs(m.timeEpochMs),
        percent: m.percent,
        source: m.source,
        id: m.id,
        isOpenVitalsEntry: m.isOpenVitalsEntry,
      );

  @override
  Future<List<WeightEntry>> readWeightEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final msgs = await _catch(
      () => _api.readWeightEntries(
        _dayStart(start).millisecondsSinceEpoch,
        _dayEnd(end).millisecondsSinceEpoch,
      ),
      const <WeightEntryMsg>[],
    );
    return [for (final m in msgs) _weightEntry(m)];
  }

  @override
  Future<WeightEntry?> readLatestWeight() async {
    final m = await _catch(() => _api.readLatestWeight(), null);
    return m == null ? null : _weightEntry(m);
  }

  @override
  Future<List<HeightEntry>> readHeightEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final msgs = await _catch(
      () => _api.readHeightEntries(
        _dayStart(start).millisecondsSinceEpoch,
        _dayEnd(end).millisecondsSinceEpoch,
      ),
      const <HeightEntryMsg>[],
    );
    return [for (final m in msgs) _heightEntry(m)];
  }

  @override
  Future<HeightEntry?> readLatestHeightEntry() async {
    final m = await _catch(() => _api.readLatestHeightEntry(), null);
    return m == null ? null : _heightEntry(m);
  }

  @override
  Future<double?> readLatestHeight() async =>
      (await readLatestHeightEntry())?.heightCm;

  @override
  Future<List<BodyFatEntry>> readBodyFatEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final msgs = await _catch(
      () => _api.readBodyFatEntries(
        _dayStart(start).millisecondsSinceEpoch,
        _dayEnd(end).millisecondsSinceEpoch,
      ),
      const <BodyFatEntryMsg>[],
    );
    return [for (final m in msgs) _bodyFatEntry(m)];
  }

  @override
  Future<double?> readLatestBodyFat() async {
    final m = await _catch(() => _api.readLatestBodyFat(), null);
    return m?.percent;
  }

  @override
  Future<List<LeanBodyMassEntry>> readLeanBodyMassEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final msgs = await _catch(
      () => _api.readLeanBodyMassEntries(
        _dayStart(start).millisecondsSinceEpoch,
        _dayEnd(end).millisecondsSinceEpoch,
      ),
      const <BodyMassEntryMsg>[],
    );
    return [
      for (final m in msgs)
        LeanBodyMassEntry(
            time: _fromMs(m.timeEpochMs), massKg: m.massKg, source: m.source),
    ];
  }

  @override
  Future<double?> readLatestLeanBodyMass() async {
    final m = await _catch(() => _api.readLatestLeanBodyMass(), null);
    return m?.massKg;
  }

  @override
  Future<List<BmrEntry>> readBmrEntries(LocalDate start, LocalDate end) async {
    final msgs = await _catch(
      () => _api.readBmrEntries(
        _dayStart(start).millisecondsSinceEpoch,
        _dayEnd(end).millisecondsSinceEpoch,
      ),
      const <BmrEntryMsg>[],
    );
    return [
      for (final m in msgs)
        BmrEntry(
            time: _fromMs(m.timeEpochMs),
            kcalPerDay: m.kcalPerDay,
            source: m.source),
    ];
  }

  @override
  Future<double?> readLatestBMR() async {
    final m = await _catch(() => _api.readLatestBmr(), null);
    return m?.kcalPerDay;
  }

  @override
  Future<List<BoneMassEntry>> readBoneMassEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final msgs = await _catch(
      () => _api.readBoneMassEntries(
        _dayStart(start).millisecondsSinceEpoch,
        _dayEnd(end).millisecondsSinceEpoch,
      ),
      const <BodyMassEntryMsg>[],
    );
    return [
      for (final m in msgs)
        BoneMassEntry(
            time: _fromMs(m.timeEpochMs), massKg: m.massKg, source: m.source),
    ];
  }

  @override
  Future<double?> readLatestBoneMass() async {
    final m = await _catch(() => _api.readLatestBoneMass(), null);
    return m?.massKg;
  }

  @override
  Future<List<BodyWaterMassEntry>> readBodyWaterMassEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final msgs = await _catch(
      () => _api.readBodyWaterMassEntries(
        _dayStart(start).millisecondsSinceEpoch,
        _dayEnd(end).millisecondsSinceEpoch,
      ),
      const <BodyMassEntryMsg>[],
    );
    return [
      for (final m in msgs)
        BodyWaterMassEntry(
            time: _fromMs(m.timeEpochMs), massKg: m.massKg, source: m.source),
    ];
  }

  @override
  Future<double?> readLatestBodyWaterMass() async {
    final m = await _catch(() => _api.readLatestBodyWaterMass(), null);
    return m?.massKg;
  }

  @override
  Future<BodyMeasurementEntry?> readBodyMeasurementEntry(
    BodyMeasurementType type,
    String id,
  ) async {
    final m = await _catch(
      () => _api.readBodyMeasurementEntry(_bodyTypeMsg(type), id),
      null,
    );
    return m == null
        ? null
        : BodyMeasurementEntry(
            id: m.id,
            type: _bodyType(m.type),
            time: _fromMs(m.timeEpochMs),
            value: m.value,
            source: m.source,
            isOpenVitalsEntry: m.isOpenVitalsEntry,
          );
  }

  // ── Heart ─────────────────────────────────────────────────────────────────

  @override
  Future<List<HeartRateSample>> readHeartRateSamples(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('HeartRate', start, end);
    return [
      for (final m in maps) ...HealthRecordJson.heartRateSamples(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<List<HeartRateSample>> readRawHeartRateSamples(
    DateTime start,
    DateTime end,
  ) =>
      readHeartRateSamples(start, end);

  @override
  Future<int?> readAvgHeartRate(LocalDate date) async {
    final samples = await readHeartRateSamples(_dayStart(date), _dayEnd(date));
    if (samples.isEmpty) return null;
    final sum = samples.fold<int>(0, (a, s) => a + s.beatsPerMinute);
    return (sum / samples.length).round();
  }

  @override
  Future<List<HeartRateSummary>> readDailyHeartRateSummaries(
    LocalDate start,
    LocalDate end,
  ) async {
    final samples = await readHeartRateSamples(_dayStart(start), _dayEnd(end));
    return HealthRecordJson.dailyHeartRateSummaries(samples);
  }

  @override
  Future<List<RestingHeartRateSample>> readRestingHeartRateSamples(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('RestingHeartRate', start, end);
    return [
      for (final m in maps) HealthRecordJson.restingHeartRateSample(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<int?> readRestingHeartRate(LocalDate date) async {
    final samples =
        await readRestingHeartRateSamples(_dayStart(date), _dayEnd(date));
    return samples.isEmpty ? null : samples.last.beatsPerMinute;
  }

  @override
  Future<List<DailyRestingHR>> readDailyRestingHR(
    LocalDate start,
    LocalDate end,
  ) async {
    final samples =
        await readRestingHeartRateSamples(_dayStart(start), _dayEnd(end));
    return HealthRecordJson.dailyRestingHR(samples);
  }

  @override
  Future<List<HrvSample>> readHrvSamples(DateTime start, DateTime end) async {
    final maps = await _read('HeartRateVariabilityRmssd', start, end);
    return [
      for (final m in maps) HealthRecordJson.hrvSample(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<double?> readHrvRmssd(LocalDate date) async {
    final samples = await readHrvSamples(_dayStart(date), _dayEnd(date));
    if (samples.isEmpty) return null;
    final sum = samples.fold<double>(0, (a, s) => a + s.rmssdMs);
    return sum / samples.length;
  }

  @override
  Future<List<DailyHrv>> readDailyHRV(LocalDate start, LocalDate end) async {
    final samples = await readHrvSamples(_dayStart(start), _dayEnd(end));
    return HealthRecordJson.dailyHrv(samples);
  }

  // ── Vitals (Phase 3) — typed via native VitalsHealthReader ──────────────────

  VitalsMeasurementTypeMsg _vitalsTypeMsg(VitalsMeasurementType type) =>
      switch (type) {
        VitalsMeasurementType.bloodPressure =>
          VitalsMeasurementTypeMsg.bloodPressure,
        VitalsMeasurementType.spo2 => VitalsMeasurementTypeMsg.spo2,
        VitalsMeasurementType.respiratoryRate =>
          VitalsMeasurementTypeMsg.respiratoryRate,
        VitalsMeasurementType.bodyTemperature =>
          VitalsMeasurementTypeMsg.bodyTemperature,
      };

  VitalsMeasurementType _vitalsType(VitalsMeasurementTypeMsg type) =>
      switch (type) {
        VitalsMeasurementTypeMsg.bloodPressure =>
          VitalsMeasurementType.bloodPressure,
        VitalsMeasurementTypeMsg.spo2 => VitalsMeasurementType.spo2,
        VitalsMeasurementTypeMsg.respiratoryRate =>
          VitalsMeasurementType.respiratoryRate,
        VitalsMeasurementTypeMsg.bodyTemperature =>
          VitalsMeasurementType.bodyTemperature,
      };

  BloodPressureEntry _bloodPressureEntry(BloodPressureEntryMsg m) =>
      BloodPressureEntry(
        time: _fromMs(m.timeEpochMs),
        systolicMmHg: m.systolicMmHg,
        diastolicMmHg: m.diastolicMmHg,
        source: m.source,
        id: m.id,
        isOpenVitalsEntry: m.isOpenVitalsEntry,
      );

  SpO2Entry _spO2Entry(SpO2EntryMsg m) => SpO2Entry(
        time: _fromMs(m.timeEpochMs),
        percent: m.percent,
        source: m.source,
        id: m.id,
        isOpenVitalsEntry: m.isOpenVitalsEntry,
      );

  Vo2MaxEntry _vo2MaxEntry(Vo2MaxEntryMsg m) => Vo2MaxEntry(
        time: _fromMs(m.timeEpochMs),
        vo2MaxMlPerKgPerMin: m.vo2MaxMlPerKgPerMin,
        source: m.source,
      );

  @override
  Future<List<BloodPressureEntry>> readBloodPressureEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readBloodPressureEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <BloodPressureEntryMsg>[],
    );
    return [for (final m in msgs) _bloodPressureEntry(m)]
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<BloodPressureEntry?> readLatestBloodPressure(LocalDate date) async {
    final m = await _catch(
      () => _api.readLatestBloodPressure(
        _dayStart(date).millisecondsSinceEpoch,
        _dayEnd(date).millisecondsSinceEpoch,
      ),
      null,
    );
    return m == null ? null : _bloodPressureEntry(m);
  }

  @override
  Future<List<SpO2Entry>> readSpO2Entries(DateTime start, DateTime end) async {
    final msgs = await _catch(
      () => _api.readSpO2Entries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <SpO2EntryMsg>[],
    );
    return [for (final m in msgs) _spO2Entry(m)]
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<SpO2Entry?> readLatestSpO2(LocalDate date) async {
    final m = await _catch(
      () => _api.readLatestSpO2(
        _dayStart(date).millisecondsSinceEpoch,
        _dayEnd(date).millisecondsSinceEpoch,
      ),
      null,
    );
    return m == null ? null : _spO2Entry(m);
  }

  @override
  Future<List<RespiratoryRateEntry>> readRespiratoryRateEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readRespiratoryRateEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <RespiratoryRateEntryMsg>[],
    );
    return [
      for (final m in msgs)
        RespiratoryRateEntry(
          time: _fromMs(m.timeEpochMs),
          breathsPerMinute: m.breathsPerMinute,
          source: m.source,
          id: m.id,
          isOpenVitalsEntry: m.isOpenVitalsEntry,
        ),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<List<BodyTempEntry>> readBodyTemperatureEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readBodyTemperatureEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <BodyTempEntryMsg>[],
    );
    return [
      for (final m in msgs)
        BodyTempEntry(
          time: _fromMs(m.timeEpochMs),
          temperatureCelsius: m.temperatureCelsius,
          source: m.source,
          id: m.id,
          isOpenVitalsEntry: m.isOpenVitalsEntry,
        ),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<List<Vo2MaxEntry>> readVo2MaxEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readVo2MaxEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <Vo2MaxEntryMsg>[],
    );
    return [for (final m in msgs) _vo2MaxEntry(m)]
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<Vo2MaxEntry?> readLatestVo2Max(LocalDate date) async {
    final m = await _catch(
      () => _api.readLatestVo2Max(
        _dayStart(date).millisecondsSinceEpoch,
        _dayEnd(date).millisecondsSinceEpoch,
      ),
      null,
    );
    return m == null ? null : _vo2MaxEntry(m);
  }

  @override
  Future<List<BloodGlucoseEntry>> readBloodGlucoseEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readBloodGlucoseEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <BloodGlucoseEntryMsg>[],
    );
    return [
      for (final m in msgs)
        BloodGlucoseEntry(
          time: _fromMs(m.timeEpochMs),
          millimolesPerLiter: m.millimolesPerLiter,
          specimenSource: m.specimenSource,
          mealType: m.mealType,
          relationToMeal: m.relationToMeal,
          source: m.source,
        ),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<List<SkinTemperatureEntry>> readSkinTemperatureEntries(
    DateTime start,
    DateTime end,
  ) async {
    if (!isSkinTemperatureAvailable()) return const <SkinTemperatureEntry>[];
    final msgs = await _catch(
      () => _api.readSkinTemperatureEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <SkinTemperatureEntryMsg>[],
    );
    return [
      for (final m in msgs)
        SkinTemperatureEntry(
          startTime: _fromMs(m.startEpochMs),
          endTime: _fromMs(m.endEpochMs),
          baselineCelsius: m.baselineCelsius,
          averageDeltaCelsius: m.averageDeltaCelsius,
          minDeltaCelsius: m.minDeltaCelsius,
          maxDeltaCelsius: m.maxDeltaCelsius,
          measurementLocation: m.measurementLocation,
          source: m.source,
        ),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  // ── Sleep ─────────────────────────────────────────────────────────────────

  @override
  Future<List<SleepData>> readSleepSessions(DateTime start, DateTime end) async {
    final maps = await _read('Sleep', start, end);
    final sessions = [
      for (final m in maps) HealthRecordJson.sleepData(m),
    ]..sort((a, b) => a.startTime.compareTo(b.startTime));
    return mergeSleepSessions(sessions);
  }

  @override
  Future<SleepData?> readSleepSession(String id) async {
    final map = await _readOne('Sleep', id);
    return map == null ? null : HealthRecordJson.sleepData(map);
  }

  @override
  Future<SleepReadData> readSleepData(
    LocalDate startDate,
    LocalDate endDate,
    SleepRangeMode sleepRangeMode,
  ) async {
    // Widen by a day on each side so sessions crossing midnight are captured.
    final sessions = await readSleepSessions(
      _dayStart(startDate.minusDays(1)),
      _dayEnd(endDate),
    );
    final durationByDate = <LocalDate, int>{};
    for (final session in sessions) {
      final date = LocalDate.fromDateTime(session.startTime.toLocal());
      durationByDate[date] = (durationByDate[date] ?? 0) + session.durationMs;
    }
    final dates = durationByDate.keys.toList()..sort();
    return SleepReadData(
      sessions: sessions,
      dailyAggregateDurations: [
        for (final date in dates)
          DailySleepDuration(date: date, durationMs: durationByDate[date]!),
      ],
    );
  }

  // ── Cycle (Phase 4) — typed via native CycleHealthReader (read-only) ────────

  @override
  Future<List<MenstruationFlowEntry>> readMenstruationFlowEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readMenstruationFlowEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <MenstruationFlowEntryMsg>[],
    );
    return [
      for (final m in msgs)
        MenstruationFlowEntry(
          time: _fromMs(m.timeEpochMs),
          flow: m.flow,
          source: m.source,
        ),
    ];
  }

  @override
  Future<List<MenstruationPeriodEntry>> readMenstruationPeriods(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readMenstruationPeriods(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <MenstruationPeriodEntryMsg>[],
    );
    return [
      for (final m in msgs)
        MenstruationPeriodEntry(
          startTime: _fromMs(m.startEpochMs),
          endTime: _fromMs(m.endEpochMs),
          source: m.source,
        ),
    ];
  }

  @override
  Future<List<OvulationTestEntry>> readOvulationTests(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readOvulationTests(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <OvulationTestEntryMsg>[],
    );
    return [
      for (final m in msgs)
        OvulationTestEntry(
          time: _fromMs(m.timeEpochMs),
          result: m.result,
          source: m.source,
        ),
    ];
  }

  @override
  Future<List<CervicalMucusEntry>> readCervicalMucusEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readCervicalMucusEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <CervicalMucusEntryMsg>[],
    );
    return [
      for (final m in msgs)
        CervicalMucusEntry(
          time: _fromMs(m.timeEpochMs),
          appearance: m.appearance,
          sensation: m.sensation,
          source: m.source,
        ),
    ];
  }

  @override
  Future<List<BasalBodyTemperatureEntry>> readBasalBodyTemperatureEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readBasalBodyTemperatureEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <BasalBodyTemperatureEntryMsg>[],
    );
    return [
      for (final m in msgs)
        BasalBodyTemperatureEntry(
          time: _fromMs(m.timeEpochMs),
          temperatureCelsius: m.temperatureCelsius,
          measurementLocation: m.measurementLocation,
          source: m.source,
        ),
    ];
  }

  @override
  Future<List<IntermenstrualBleedingEntry>> readIntermenstrualBleedingEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readIntermenstrualBleedingEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <IntermenstrualBleedingEntryMsg>[],
    );
    return [
      for (final m in msgs)
        IntermenstrualBleedingEntry(
          time: _fromMs(m.timeEpochMs),
          source: m.source,
        ),
    ];
  }

  @override
  Future<List<SexualActivityEntry>> readSexualActivityEntries(
    DateTime start,
    DateTime end,
  ) async {
    final msgs = await _catch(
      () => _api.readSexualActivityEntries(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <SexualActivityEntryMsg>[],
    );
    return [
      for (final m in msgs)
        SexualActivityEntry(
          time: _fromMs(m.timeEpochMs),
          protectionUsed: m.protectionUsed,
          source: m.source,
        ),
    ];
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> _insert(Map<String, dynamic> record) async {
    await _catch(
      () => _api.insertRecordsJson([jsonEncode(record)]),
      const <String>[],
    );
  }

  @override
  Future<String> writeHydrationEntry(HydrationWriteRequest request) =>
      _api.writeHydrationEntry(
        HydrationWriteRequestMsg(
          timeEpochMs: request.time.millisecondsSinceEpoch,
          volumeLiters: request.volumeLiters,
          drinkId: request.drinkId,
        ),
      );

  @override
  Future<void> updateHydrationEntry(
    String id,
    HydrationWriteRequest request,
  ) =>
      _api.updateHydrationEntry(
        id,
        HydrationWriteRequestMsg(
          timeEpochMs: request.time.millisecondsSinceEpoch,
          volumeLiters: request.volumeLiters,
          drinkId: request.drinkId,
        ),
      );

  @override
  Future<String?> deleteHydrationEntry(String id) =>
      // Returns the deleted record's clientRecordId (for paired-nutrition
      // cleanup, handled in the nutrition phase); ownership is enforced natively.
      _catch(() => _api.deleteHydrationEntry(id), null);

  // ── Mindfulness (Phase 2) — typed via native MindfulnessHealthReader ────────

  MindfulnessSession _mindfulnessSession(MindfulnessSessionMsg m) =>
      MindfulnessSession(
        id: m.id,
        title: m.title,
        startTime: _fromMs(m.startEpochMs),
        endTime: _fromMs(m.endEpochMs),
        durationMs: m.durationMs,
        source: m.source,
        isOpenVitalsEntry: m.isOpenVitalsEntry,
      );

  @override
  Future<List<MindfulnessSession>> readMindfulnessSessions(
    DateTime start,
    DateTime end,
  ) async {
    if (!isMindfulnessSessionAvailable()) return const <MindfulnessSession>[];
    final msgs = await _catch(
      () => _api.readMindfulnessSessions(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ),
      const <MindfulnessSessionMsg>[],
    );
    return [for (final m in msgs) _mindfulnessSession(m)];
  }

  @override
  Future<MindfulnessSession?> readMindfulnessSession(String id) async {
    if (!isMindfulnessSessionAvailable()) return null;
    final m = await _catch(() => _api.readMindfulnessSession(id), null);
    return m == null ? null : _mindfulnessSession(m);
  }

  @override
  Future<int> readMindfulnessMinutes(LocalDate date) async {
    if (!isMindfulnessSessionAvailable()) return 0;
    return _catch(
      () => _api.readMindfulnessMinutes(
        _dayStart(date).millisecondsSinceEpoch,
        _dayEnd(date).millisecondsSinceEpoch,
      ),
      0,
    );
  }

  @override
  Future<String> writeMindfulnessSessionEntry(
    MindfulnessSessionWriteRequest request,
  ) =>
      _api.writeMindfulnessSessionEntry(
        MindfulnessSessionWriteRequestMsg(
          title: request.title,
          startEpochMs: request.startTime.millisecondsSinceEpoch,
          endEpochMs: request.endTime.millisecondsSinceEpoch,
        ),
      );

  @override
  Future<void> updateMindfulnessSessionEntry(
    String id,
    MindfulnessSessionWriteRequest request,
  ) =>
      _api.updateMindfulnessSessionEntry(
        id,
        MindfulnessSessionWriteRequestMsg(
          title: request.title,
          startEpochMs: request.startTime.millisecondsSinceEpoch,
          endEpochMs: request.endTime.millisecondsSinceEpoch,
        ),
      );

  @override
  Future<void> deleteMindfulnessSessionEntry(String id) =>
      _api.deleteMindfulnessSessionEntry(id);

  @override
  Future<String> writeBodyMeasurementEntry(
    BodyMeasurementWriteRequest request,
  ) =>
      _api.writeBodyMeasurementEntry(
        BodyMeasurementWriteRequestMsg(
          type: _bodyTypeMsg(request.type),
          timeEpochMs: request.time.millisecondsSinceEpoch,
          value: request.value,
        ),
      );

  @override
  Future<void> updateBodyMeasurementEntry(
    String id,
    BodyMeasurementWriteRequest request,
  ) =>
      _api.updateBodyMeasurementEntry(
        id,
        BodyMeasurementWriteRequestMsg(
          type: _bodyTypeMsg(request.type),
          timeEpochMs: request.time.millisecondsSinceEpoch,
          value: request.value,
        ),
      );

  @override
  Future<void> deleteBodyMeasurementEntry(
    BodyMeasurementType type,
    String id,
  ) =>
      _api.deleteBodyMeasurementEntry(_bodyTypeMsg(type), id);

  VitalsMeasurementWriteRequestMsg _vitalsWriteMsg(
    VitalsMeasurementWriteRequest request,
  ) =>
      VitalsMeasurementWriteRequestMsg(
        type: _vitalsTypeMsg(request.type),
        timeEpochMs: request.time.millisecondsSinceEpoch,
        value: request.value,
        secondaryValue: request.secondaryValue,
      );

  @override
  Future<String> writeVitalsMeasurementEntry(
    VitalsMeasurementWriteRequest request,
  ) =>
      _api.writeVitalsMeasurementEntry(_vitalsWriteMsg(request));

  @override
  Future<VitalsMeasurementEntry?> readVitalsMeasurementEntry(
    VitalsMeasurementType type,
    String id,
  ) async {
    final m = await _catch(
      () => _api.readVitalsMeasurementEntry(_vitalsTypeMsg(type), id),
      null,
    );
    return m == null
        ? null
        : VitalsMeasurementEntry(
            id: m.id,
            type: _vitalsType(m.type),
            time: _fromMs(m.timeEpochMs),
            value: m.value,
            secondaryValue: m.secondaryValue,
            source: m.source,
            isOpenVitalsEntry: m.isOpenVitalsEntry,
          );
  }

  @override
  Future<void> updateVitalsMeasurementEntry(
    String id,
    VitalsMeasurementWriteRequest request,
  ) =>
      _api.updateVitalsMeasurementEntry(id, _vitalsWriteMsg(request));

  @override
  Future<void> deleteVitalsMeasurementEntry(
    VitalsMeasurementType type,
    String id,
  ) =>
      _api.deleteVitalsMeasurementEntry(_vitalsTypeMsg(type), id);

  @override
  Future<String> writeNutritionEntry(NutritionWriteRequest request) async {
    final clientRecordId =
        'openvitals_nutrition_${request.time.millisecondsSinceEpoch}_${_newId()}';
    await _insert(
      HealthRecordJson.nutritionRecord(
        time: request.time,
        name: request.name,
        nutrientValues: request.nutrientValues,
        clientRecordId: clientRecordId,
      ),
    );
    return clientRecordId;
  }

  @override
  Future<String?> deleteNutritionEntry(String id) async {
    await _catch(
      () => _api.deleteRecordsByIds('Nutrition', [id]),
      null,
    );
    return id;
  }

  @override
  Future<String> writeActivityEntry(ActivityWriteRequest request) async {
    final clientRecordId =
        'openvitals_activity_${request.startTime.millisecondsSinceEpoch}_${_newId()}';
    final fields = <String, dynamic>{
      'exerciseType': request.exerciseType,
      if (request.title != null) 'title': request.title,
      if (request.notes != null) 'notes': request.notes,
      if (request.plannedExerciseSessionId != null)
        'plannedExerciseSessionId': request.plannedExerciseSessionId,
      if (request.exerciseSegments.isNotEmpty)
        'segments': [
          for (final s in request.exerciseSegments)
            {
              'startEpochMs': s.startTime.millisecondsSinceEpoch,
              'endEpochMs': s.endTime.millisecondsSinceEpoch,
              'segmentType': s.segmentType,
              'repetitions': s.repetitions,
            },
        ],
      if (request.laps.isNotEmpty)
        'laps': [
          for (final l in request.laps)
            {
              'startEpochMs': l.startTime.millisecondsSinceEpoch,
              'endEpochMs': l.endTime.millisecondsSinceEpoch,
              if (l.lengthMeters != null) 'lengthMeters': l.lengthMeters,
            },
        ],
      if (request.routePoints.isNotEmpty)
        'route': {
          'points': [
            for (final p in request.routePoints)
              {
                'timeEpochMs': p.time.millisecondsSinceEpoch,
                'latitude': p.latitude,
                'longitude': p.longitude,
                if (p.altitudeMeters != null) 'altitudeMeters': p.altitudeMeters,
                if (p.horizontalAccuracyMeters != null)
                  'horizontalAccuracyMeters': p.horizontalAccuracyMeters,
                if (p.verticalAccuracyMeters != null)
                  'verticalAccuracyMeters': p.verticalAccuracyMeters,
              },
          ],
        },
    };
    await _insert(
      HealthRecordJson.intervalRecord(
        'ExerciseSession',
        request.startTime,
        request.endTime,
        clientRecordId,
        fields: fields,
      ),
    );
    return clientRecordId;
  }

  @override
  Future<void> deleteActivityEntry(String id) async {
    await _catch(
      () => _api.deleteRecordsByIds('ExerciseSession', [id]),
      null,
    );
  }

  // ── Apple Health import ────────────────────────────────────────────────────

  @override
  Future<void> insertImportedRecords(List<ImportRecord> records) async {
    if (records.isEmpty) return;
    final jsons = [
      for (final record in records)
        jsonEncode(HealthRecordJson.importRecord(record)),
    ];
    // Let failures propagate so the import service can classify duplicates /
    // failures and retry individually (Kotlin parity).
    await _api.insertRecordsJson(jsons);
  }

  @override
  Future<Set<String>> findMatchingImportedClientRecordIds(
    String recordType,
    DateTime start,
    DateTime end,
    Set<String> wantedIds,
  ) async {
    if (wantedIds.isEmpty) return const <String>{};
    final schemaType = HealthRecordJson.schemaTypeForImport(recordType);
    if (schemaType == null) return const <String>{};
    final existing = await _catch(
      () => _api.filterExistingClientIds(schemaType, wantedIds.toList()),
      const <String>[],
    );
    return existing.toSet();
  }
}
