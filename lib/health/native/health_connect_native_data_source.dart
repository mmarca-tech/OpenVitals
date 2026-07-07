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

  @override
  Future<double?> readHydrationLiters(LocalDate date) async {
    final agg = await _aggregate(
      const ['Hydration.volume'],
      _dayStart(date),
      _dayEnd(date),
    );
    return agg['Hydration.volume'];
  }

  @override
  Future<List<HydrationEntry>> readHydrationEntries(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('Hydration', start, end);
    return [
      for (final m in maps) HealthRecordJson.hydrationEntry(m, appPackageName),
    ];
  }

  @override
  Future<HydrationEntry?> readHydrationEntry(String id) async {
    final map = await _readOne('Hydration', id);
    return map == null
        ? null
        : HealthRecordJson.hydrationEntry(map, appPackageName);
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  @override
  Future<List<WeightEntry>> readWeightEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final maps = await _read('Weight', _dayStart(start), _dayEnd(end));
    return [
      for (final m in maps) HealthRecordJson.weightEntry(m, appPackageName),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<WeightEntry?> readLatestWeight() async {
    final end = LocalDate.now();
    final entries = await readWeightEntries(end.minusDays(3650), end);
    return entries.isEmpty ? null : entries.last;
  }

  @override
  Future<List<HeightEntry>> readHeightEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final maps = await _read('Height', _dayStart(start), _dayEnd(end));
    return [
      for (final m in maps) HealthRecordJson.heightEntry(m, appPackageName),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<HeightEntry?> readLatestHeightEntry() async {
    final end = LocalDate.now();
    final entries = await readHeightEntries(end.minusDays(3650), end);
    return entries.isEmpty ? null : entries.last;
  }

  @override
  Future<double?> readLatestHeight() async =>
      (await readLatestHeightEntry())?.heightCm;

  @override
  Future<List<BodyFatEntry>> readBodyFatEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final maps = await _read('BodyFat', _dayStart(start), _dayEnd(end));
    return [
      for (final m in maps) HealthRecordJson.bodyFatEntry(m, appPackageName),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<double?> readLatestBodyFat() async {
    final end = LocalDate.now();
    final entries = await readBodyFatEntries(end.minusDays(3650), end);
    return entries.isEmpty ? null : entries.last.percent;
  }

  @override
  Future<List<LeanBodyMassEntry>> readLeanBodyMassEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final maps = await _read('LeanBodyMass', _dayStart(start), _dayEnd(end));
    return [
      for (final m in maps) HealthRecordJson.leanBodyMassEntry(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<double?> readLatestLeanBodyMass() async {
    final end = LocalDate.now();
    final entries = await readLeanBodyMassEntries(end.minusDays(3650), end);
    return entries.isEmpty ? null : entries.last.massKg;
  }

  @override
  Future<List<BmrEntry>> readBmrEntries(LocalDate start, LocalDate end) async {
    final maps = await _read('BasalMetabolicRate', _dayStart(start), _dayEnd(end));
    return [
      for (final m in maps) HealthRecordJson.bmrEntry(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<double?> readLatestBMR() async {
    final end = LocalDate.now();
    final entries = await readBmrEntries(end.minusDays(3650), end);
    return entries.isEmpty ? null : entries.last.kcalPerDay;
  }

  @override
  Future<List<BoneMassEntry>> readBoneMassEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final maps = await _read('BoneMass', _dayStart(start), _dayEnd(end));
    return [
      for (final m in maps) HealthRecordJson.boneMassEntry(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<double?> readLatestBoneMass() async {
    final end = LocalDate.now();
    final entries = await readBoneMassEntries(end.minusDays(3650), end);
    return entries.isEmpty ? null : entries.last.massKg;
  }

  @override
  Future<List<BodyWaterMassEntry>> readBodyWaterMassEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final maps = await _read('BodyWaterMass', _dayStart(start), _dayEnd(end));
    return [
      for (final m in maps) HealthRecordJson.bodyWaterMassEntry(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<double?> readLatestBodyWaterMass() async {
    final end = LocalDate.now();
    final entries = await readBodyWaterMassEntries(end.minusDays(3650), end);
    return entries.isEmpty ? null : entries.last.massKg;
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

  // ── Vitals ────────────────────────────────────────────────────────────────

  @override
  Future<List<BloodPressureEntry>> readBloodPressureEntries(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('BloodPressure', start, end);
    return [
      for (final m in maps) HealthRecordJson.bloodPressureEntry(m, appPackageName),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<BloodPressureEntry?> readLatestBloodPressure(LocalDate date) async {
    final entries = await readBloodPressureEntries(_dayStart(date), _dayEnd(date));
    return entries.isEmpty ? null : entries.last;
  }

  @override
  Future<List<SpO2Entry>> readSpO2Entries(DateTime start, DateTime end) async {
    final maps = await _read('OxygenSaturation', start, end);
    return [
      for (final m in maps) HealthRecordJson.spO2Entry(m, appPackageName),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<SpO2Entry?> readLatestSpO2(LocalDate date) async {
    final entries = await readSpO2Entries(_dayStart(date), _dayEnd(date));
    return entries.isEmpty ? null : entries.last;
  }

  @override
  Future<List<RespiratoryRateEntry>> readRespiratoryRateEntries(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('RespiratoryRate', start, end);
    return [
      for (final m in maps)
        HealthRecordJson.respiratoryRateEntry(m, appPackageName),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<List<BodyTempEntry>> readBodyTemperatureEntries(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('BodyTemperature', start, end);
    return [
      for (final m in maps) HealthRecordJson.bodyTempEntry(m, appPackageName),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<List<Vo2MaxEntry>> readVo2MaxEntries(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('Vo2Max', start, end);
    return [
      for (final m in maps) HealthRecordJson.vo2MaxEntry(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<Vo2MaxEntry?> readLatestVo2Max(LocalDate date) async {
    final entries = await readVo2MaxEntries(_dayStart(date), _dayEnd(date));
    return entries.isEmpty ? null : entries.last;
  }

  @override
  Future<List<BloodGlucoseEntry>> readBloodGlucoseEntries(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('BloodGlucose', start, end);
    return [
      for (final m in maps) HealthRecordJson.bloodGlucoseEntry(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<List<SkinTemperatureEntry>> readSkinTemperatureEntries(
    DateTime start,
    DateTime end,
  ) async {
    if (!isSkinTemperatureAvailable()) return const <SkinTemperatureEntry>[];
    final maps = await _read('SkinTemperature', start, end);
    return [
      for (final m in maps) HealthRecordJson.skinTemperatureEntry(m),
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

  // ── Cycle ─────────────────────────────────────────────────────────────────

  @override
  Future<List<MenstruationFlowEntry>> readMenstruationFlowEntries(
    DateTime start,
    DateTime end,
  ) async {
    final maps = await _read('MenstruationFlow', start, end);
    return [
      for (final m in maps) HealthRecordJson.menstruationFlowEntry(m),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> _insert(Map<String, dynamic> record) async {
    await _catch(
      () => _api.insertRecordsJson([jsonEncode(record)]),
      const <String>[],
    );
  }

  @override
  Future<String> writeHydrationEntry(HydrationWriteRequest request) async {
    final drinkSuffix =
        request.drinkId == null ? '' : '_drink_${request.drinkId}';
    final clientRecordId =
        'openvitals_hydration_${request.time.millisecondsSinceEpoch}${drinkSuffix}_${_newId()}';
    await _insert(
      HealthRecordJson.intervalRecord(
        'Hydration',
        request.time,
        request.time,
        clientRecordId,
        fields: {'volumeLiters': request.volumeLiters},
      ),
    );
    return clientRecordId;
  }

  @override
  Future<String?> deleteHydrationEntry(String id) async {
    await _catch(
      () => _api.deleteRecordsByIds('Hydration', [id]),
      null,
    );
    // Paired-nutrition cleanup by clientRecordId is a no-op on the base source.
    return null;
  }

  @override
  Future<String> writeBodyMeasurementEntry(
    BodyMeasurementWriteRequest request,
  ) async {
    final clientRecordId =
        'openvitals_body_${request.type.storageName.toLowerCase()}_${request.time.millisecondsSinceEpoch}_${_newId()}';
    final (recordType, fields) = switch (request.type) {
      BodyMeasurementType.weight => ('Weight', {'weightKg': request.value}),
      // The domain stores centimetres; HEIGHT is written in metres.
      BodyMeasurementType.height => (
          'Height',
          {'heightMeters': request.value / 100.0},
        ),
      BodyMeasurementType.bodyFat => ('BodyFat', {'percentage': request.value}),
    };
    await _insert(
      HealthRecordJson.instantRecord(
        recordType,
        request.time,
        clientRecordId,
        fields: fields,
      ),
    );
    return clientRecordId;
  }

  @override
  Future<String> writeVitalsMeasurementEntry(
    VitalsMeasurementWriteRequest request,
  ) async {
    final clientRecordId =
        'openvitals_vitals_${request.type.storageName.toLowerCase()}_${request.time.millisecondsSinceEpoch}_${_newId()}';
    final (recordType, fields) = switch (request.type) {
      VitalsMeasurementType.bloodPressure => (
          'BloodPressure',
          {
            'systolicMmHg': request.value,
            'diastolicMmHg': request.secondaryValue ?? 0.0,
          },
        ),
      VitalsMeasurementType.spo2 => ('OxygenSaturation', {'percentage': request.value}),
      VitalsMeasurementType.respiratoryRate => (
          'RespiratoryRate',
          {'rate': request.value},
        ),
      VitalsMeasurementType.bodyTemperature => (
          'BodyTemperature',
          {'temperatureCelsius': request.value},
        ),
    };
    await _insert(
      HealthRecordJson.instantRecord(
        recordType,
        request.time,
        clientRecordId,
        fields: fields,
      ),
    );
    return clientRecordId;
  }

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
