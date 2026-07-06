import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:health/health.dart';

import '../core/time/local_date.dart';
import '../domain/model/activity_models.dart';
import '../domain/model/activity_session_deduplication.dart';
import '../domain/model/body_models.dart';
import '../domain/model/cycle_models.dart';
import '../domain/model/health_connect_availability.dart';
import '../domain/model/heart_models.dart';
import '../domain/model/nutrition_models.dart';
import '../domain/model/sleep_models.dart';
import '../domain/model/sleep_session_merging.dart';
import '../domain/model/vitals_models.dart';
import '../domain/preferences/sleep_range_mode.dart';
import 'health_connect_mappers.dart';
import 'health_data_source.dart';
import 'health_permissions.dart';

/// Real [HealthDataSource] over the `health` package's [Health] facade.
///
/// Every method is defensive (per-metric try/catch degrading to empty/null),
/// mirroring the Kotlin readers which swallow Health Connect failures per
/// metric. Reads the `health` package cannot express are left to the base
/// class's documented empty defaults (see `// TODO(health-pkg):` markers there).
class HealthDataSourceImpl extends HealthDataSource {
  HealthDataSourceImpl({Health? health, super.appPackageName})
      : _health = health ?? Health();

  final Health _health;
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

  Future<List<HealthDataPoint>> _read(
    List<HealthDataType> types,
    DateTime start,
    DateTime end, {
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
  }) =>
      _catch(
        () => _health.getHealthDataFromTypes(
          types: types,
          startTime: start,
          endTime: end,
          preferredUnits: preferredUnits,
        ),
        const <HealthDataPoint>[],
      );

  String _newId() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(1 << 32).toRadixString(16);
    return '${millis}_$rand';
  }

  // ── Availability / permissions ────────────────────────────────────────────

  @override
  Future<HealthConnectAvailability> availability() async {
    // TODO(health-pkg): the `health` package cannot distinguish the Kotlin
    //   NEEDS_PLAY_STORE (standalone HC without Play Store) case, so it is
    //   never returned here.
    final HealthConnectAvailability resolved;
    if (!Platform.isAndroid) {
      resolved = HealthConnectAvailability.available;
    } else {
      final status = await _catch(
        () => _health.getHealthConnectSdkStatus(),
        HealthConnectSdkStatus.sdkUnavailable,
      );
      resolved = switch (status) {
        HealthConnectSdkStatus.sdkAvailable =>
          HealthConnectAvailability.available,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          HealthConnectAvailability.needsProviderUpdate,
        HealthConnectSdkStatus.sdkUnavailable ||
        null =>
          HealthConnectAvailability.notSupported,
      };
    }
    cachedAvailability = resolved;
    return resolved;
  }

  @override
  Future<HealthConnectFeatureFlags> resolveFeatureFlags() async {
    final skin = Platform.isAndroid
        ? await _catch(() => _health.isSkinTemperatureAvailable(), false)
        : false;
    final history = Platform.isAndroid
        ? await _catch(() => _health.isHealthDataHistoryAvailable(), false)
        : false;
    final background = Platform.isAndroid
        ? await _catch(() => _health.isHealthDataInBackgroundAvailable(), false)
        : false;
    // MINDFULNESS is exposed by the health package on iOS/HealthKit only.
    final mindfulness =
        !Platform.isAndroid && _health.isDataTypeAvailable(HealthDataType.MINDFULNESS);
    final flags = HealthConnectFeatureFlags(
      skinTemperatureAvailable: skin,
      healthDataHistoryAvailable: history,
      backgroundReadAvailable: background,
      mindfulnessAvailable: mindfulness,
      plannedExerciseAvailable: false,
    );
    featureFlags = flags;
    return flags;
  }

  @override
  Future<bool> requestPermissions(Set<String> permissions) async {
    final resolved = HealthPermissionService.resolve(permissions);
    if (resolved.types.isEmpty) return false;
    return _catch(
      () => _health.requestAuthorization(
        resolved.types,
        permissions: resolved.accesses,
      ),
      false,
    );
  }

  @override
  Future<Set<String>> grantedPermissions() async {
    final granted = <String>{};
    for (final permission in permissionService.managedPermissions) {
      final mapping = HealthPermissionService.mappingFor(permission);
      if (mapping == null) continue;
      final ok = await _catch(
        () => _health.hasPermissions(
          mapping.types,
          permissions: List<HealthDataAccess>.filled(
            mapping.types.length,
            mapping.access,
          ),
        ),
        false,
      );
      if (ok == true) granted.add(permission);
    }
    return granted;
  }

  // ── Activity ──────────────────────────────────────────────────────────────

  @override
  Future<int> readSteps(LocalDate date) async =>
      (await _catch<int?>(
        () => _health.getTotalStepsInInterval(_dayStart(date), _dayEnd(date)),
        null,
      )) ??
      0;

  @override
  Future<double> readDistanceMeters(LocalDate date) async {
    final points =
        await _read([HealthDataType.DISTANCE_DELTA], _dayStart(date), _dayEnd(date));
    return points.fold<double>(
      0.0,
      (sum, p) => sum + HealthConnectMappers.numericValue(p).toDouble(),
    );
  }

  @override
  Future<int> readFloorsClimbed(LocalDate date) async {
    final points =
        await _read([HealthDataType.FLIGHTS_CLIMBED], _dayStart(date), _dayEnd(date));
    return points
        .fold<double>(
          0.0,
          (sum, p) => sum + HealthConnectMappers.numericValue(p).toDouble(),
        )
        .round();
  }

  @override
  Future<List<DailySteps>> readDailySteps(
    LocalDate startDate,
    LocalDate endDate, {
    bool includeActiveCalories = false,
  }) async {
    final result = <DailySteps>[];
    var date = startDate;
    while (!date.isAfter(endDate)) {
      final steps = await readSteps(date);
      final distance = await readDistanceMeters(date);
      double? activeCalories;
      if (includeActiveCalories) {
        final points = await _read(
          [HealthDataType.ACTIVE_ENERGY_BURNED],
          _dayStart(date),
          _dayEnd(date),
        );
        if (points.isNotEmpty) {
          activeCalories = points.fold<double>(
            0.0,
            (sum, p) => sum + HealthConnectMappers.numericValue(p).toDouble(),
          );
        }
      }
      result.add(
        DailySteps(
          date: date,
          steps: steps,
          distanceMeters: distance,
          activeCaloriesKcal: activeCalories,
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
    final points = await _read([HealthDataType.WORKOUT], start, end);
    final sessions = points
        .map((p) => HealthConnectMappers.exerciseData(p, appPackageName))
        .toList();
    return deduplicateExerciseSessions(sessions);
  }

  @override
  Future<ExerciseData?> readExerciseSession(String id) async {
    final point = await _catch(
      () => _health.getHealthDataByUUID(uuid: id, type: HealthDataType.WORKOUT),
      null,
    );
    return point == null
        ? null
        : HealthConnectMappers.exerciseData(point, appPackageName);
  }

  @override
  Future<CaloriesBurnedValue?> readCaloriesBurned(
    LocalDate date, {
    bool includeEstimatedCalories = false,
  }) async {
    final points = await _read(
      [HealthDataType.TOTAL_CALORIES_BURNED],
      _dayStart(date),
      _dayEnd(date),
    );
    if (points.isEmpty) return null;
    final kcal = points.fold<double>(
      0.0,
      (sum, p) => sum + HealthConnectMappers.numericValue(p).toDouble(),
    );
    if (kcal <= 0) return null;
    return CaloriesBurnedValue(kcal: kcal, source: CaloriesBurnedSource.recordedTotal);
  }

  @override
  Future<List<SpeedSample>> readSpeedSamples(DateTime start, DateTime end) async {
    final points = await _read([HealthDataType.SPEED], start, end);
    return [
      for (final p in points)
        SpeedSample(
          time: p.dateFrom.toUtc(),
          metersPerSecond: HealthConnectMappers.numericValue(p).toDouble(),
          source: HealthConnectMappers.sourceOf(p),
        ),
    ];
  }

  // ── Nutrition / hydration ─────────────────────────────────────────────────

  @override
  Future<double?> readCaloriesInKcal(LocalDate date) async {
    final entries = await readNutritionEntries(_dayStart(date), _dayEnd(date));
    if (entries.isEmpty) return null;
    final kcal = entries.fold<double>(0.0, (sum, e) => sum + (e.energyKcal ?? 0));
    return kcal > 0 ? kcal : null;
  }

  @override
  Future<List<NutritionEntry>> readNutritionEntries(
    DateTime start,
    DateTime end,
  ) async {
    final points = await _read([HealthDataType.NUTRITION], start, end);
    return [
      for (final p in points)
        HealthConnectMappers.nutritionEntry(p, appPackageName),
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
    final result = <DailyMacros>[];
    final dates = byDate.keys.toList()..sort();
    for (final date in dates) {
      result.add(DailyMacros(date: date, nutrientValues: byDate[date]!));
    }
    return result;
  }

  @override
  Future<double?> readHydrationLiters(LocalDate date) async {
    final points =
        await _read([HealthDataType.WATER], _dayStart(date), _dayEnd(date));
    if (points.isEmpty) return null;
    return points.fold<double>(
      0.0,
      (sum, p) => sum + HealthConnectMappers.numericValue(p).toDouble(),
    );
  }

  @override
  Future<List<HydrationEntry>> readHydrationEntries(
    DateTime start,
    DateTime end,
  ) async {
    final points = await _read([HealthDataType.WATER], start, end);
    return [
      for (final p in points)
        HealthConnectMappers.hydrationEntry(p, appPackageName),
    ];
  }

  @override
  Future<HydrationEntry?> readHydrationEntry(String id) async {
    final point = await _catch(
      () => _health.getHealthDataByUUID(uuid: id, type: HealthDataType.WATER),
      null,
    );
    return point == null
        ? null
        : HealthConnectMappers.hydrationEntry(point, appPackageName);
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  @override
  Future<List<WeightEntry>> readWeightEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final points =
        await _read([HealthDataType.WEIGHT], _dayStart(start), _dayEnd(end));
    return [
      for (final p in points) HealthConnectMappers.weightEntry(p, appPackageName),
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
    final points =
        await _read([HealthDataType.HEIGHT], _dayStart(start), _dayEnd(end));
    return [
      for (final p in points) HealthConnectMappers.heightEntry(p, appPackageName),
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
    final points = await _read(
      [HealthDataType.BODY_FAT_PERCENTAGE],
      _dayStart(start),
      _dayEnd(end),
    );
    return [
      for (final p in points) HealthConnectMappers.bodyFatEntry(p, appPackageName),
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
    final points = await _read(
      [HealthDataType.LEAN_BODY_MASS],
      _dayStart(start),
      _dayEnd(end),
    );
    return [
      for (final p in points) HealthConnectMappers.leanBodyMassEntry(p),
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
    final points = await _read(
      [HealthDataType.BASAL_ENERGY_BURNED],
      _dayStart(start),
      _dayEnd(end),
    );
    return [
      for (final p in points) HealthConnectMappers.bmrEntry(p),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<double?> readLatestBMR() async {
    final end = LocalDate.now();
    final entries = await readBmrEntries(end.minusDays(3650), end);
    return entries.isEmpty ? null : entries.last.kcalPerDay;
  }

  @override
  Future<List<BodyWaterMassEntry>> readBodyWaterMassEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final points = await _read(
      [HealthDataType.BODY_WATER_MASS],
      _dayStart(start),
      _dayEnd(end),
    );
    return [
      for (final p in points) HealthConnectMappers.bodyWaterMassEntry(p),
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
    final points = await _read([HealthDataType.HEART_RATE], start, end);
    return [
      for (final p in points) HealthConnectMappers.heartRateSample(p),
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
    return HealthConnectMappers.dailyHeartRateSummaries(samples);
  }

  @override
  Future<List<RestingHeartRateSample>> readRestingHeartRateSamples(
    DateTime start,
    DateTime end,
  ) async {
    final points = await _read([HealthDataType.RESTING_HEART_RATE], start, end);
    return [
      for (final p in points) HealthConnectMappers.restingHeartRateSample(p),
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
    return HealthConnectMappers.dailyRestingHR(samples);
  }

  @override
  Future<List<HrvSample>> readHrvSamples(DateTime start, DateTime end) async {
    final points =
        await _read([HealthDataType.HEART_RATE_VARIABILITY_RMSSD], start, end);
    return [
      for (final p in points) HealthConnectMappers.hrvSample(p),
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
    return HealthConnectMappers.dailyHrv(samples);
  }

  // ── Vitals ────────────────────────────────────────────────────────────────

  @override
  Future<List<BloodPressureEntry>> readBloodPressureEntries(
    DateTime start,
    DateTime end,
  ) async {
    // The health package returns systolic and diastolic as separate points
    // sharing the record uuid; pair them back up.
    final systolic = await _read(
      [HealthDataType.BLOOD_PRESSURE_SYSTOLIC],
      start,
      end,
    );
    final diastolic = await _read(
      [HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
      start,
      end,
    );
    final diastolicByUuid = {for (final p in diastolic) p.uuid: p};
    final entries = <BloodPressureEntry>[];
    for (final sys in systolic) {
      final dia = diastolicByUuid[sys.uuid];
      entries.add(
        BloodPressureEntry(
          time: sys.dateFrom.toUtc(),
          systolicMmHg: HealthConnectMappers.numericValue(sys).round(),
          diastolicMmHg:
              dia == null ? 0 : HealthConnectMappers.numericValue(dia).round(),
          source: HealthConnectMappers.sourceOf(sys),
          id: sys.uuid,
          isOpenVitalsEntry:
              HealthConnectMappers.isOpenVitalsRecord(sys, appPackageName),
        ),
      );
    }
    entries.sort((a, b) => a.time.compareTo(b.time));
    return entries;
  }

  @override
  Future<BloodPressureEntry?> readLatestBloodPressure(LocalDate date) async {
    final entries =
        await readBloodPressureEntries(_dayStart(date), _dayEnd(date));
    return entries.isEmpty ? null : entries.last;
  }

  @override
  Future<List<SpO2Entry>> readSpO2Entries(DateTime start, DateTime end) async {
    final points = await _read([HealthDataType.BLOOD_OXYGEN], start, end);
    return [
      for (final p in points) HealthConnectMappers.spO2Entry(p, appPackageName),
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
    final points = await _read([HealthDataType.RESPIRATORY_RATE], start, end);
    return [
      for (final p in points)
        HealthConnectMappers.respiratoryRateEntry(p, appPackageName),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<List<BodyTempEntry>> readBodyTemperatureEntries(
    DateTime start,
    DateTime end,
  ) async {
    final points = await _read([HealthDataType.BODY_TEMPERATURE], start, end);
    return [
      for (final p in points)
        HealthConnectMappers.bodyTempEntry(p, appPackageName),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<List<BloodGlucoseEntry>> readBloodGlucoseEntries(
    DateTime start,
    DateTime end,
  ) async {
    final points = await _read(
      [HealthDataType.BLOOD_GLUCOSE],
      start,
      end,
      preferredUnits: const {
        HealthDataType.BLOOD_GLUCOSE: HealthDataUnit.MILLIMOLES_PER_LITER,
      },
    );
    return [
      for (final p in points) HealthConnectMappers.bloodGlucoseEntry(p),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  @override
  Future<List<SkinTemperatureEntry>> readSkinTemperatureEntries(
    DateTime start,
    DateTime end,
  ) async {
    if (!isSkinTemperatureAvailable()) return const <SkinTemperatureEntry>[];
    final points = await _read([HealthDataType.SKIN_TEMPERATURE], start, end);
    return [
      for (final p in points) HealthConnectMappers.skinTemperatureEntry(p),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  // ── Sleep ─────────────────────────────────────────────────────────────────

  @override
  Future<List<SleepData>> readSleepSessions(DateTime start, DateTime end) async {
    final points = await _read([HealthDataType.SLEEP_SESSION], start, end);
    final sessions = points.map(HealthConnectMappers.sleepData).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return mergeSleepSessions(sessions);
  }

  @override
  Future<SleepData?> readSleepSession(String id) async {
    final point = await _catch(
      () =>
          _health.getHealthDataByUUID(uuid: id, type: HealthDataType.SLEEP_SESSION),
      null,
    );
    return point == null ? null : HealthConnectMappers.sleepData(point);
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
    final points = await _read([HealthDataType.MENSTRUATION_FLOW], start, end);
    return [
      for (final p in points) HealthConnectMappers.menstruationFlowEntry(p),
    ]..sort((a, b) => a.time.compareTo(b.time));
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  @override
  Future<String> writeHydrationEntry(HydrationWriteRequest request) async {
    final drinkSuffix =
        request.drinkId == null ? '' : '_drink_${request.drinkId}';
    final clientRecordId =
        'openvitals_hydration_${request.time.millisecondsSinceEpoch}${drinkSuffix}_${_newId()}';
    await _catch(
      () => _health.writeHealthData(
        value: request.volumeLiters,
        type: HealthDataType.WATER,
        unit: HealthDataUnit.LITER,
        startTime: request.time,
        recordingMethod: RecordingMethod.manual,
        clientRecordId: clientRecordId,
      ),
      false,
    );
    return clientRecordId;
  }

  @override
  Future<String?> deleteHydrationEntry(String id) async {
    await _catch(
      () => _health.deleteByUUID(uuid: id, type: HealthDataType.WATER),
      false,
    );
    // clientRecordId is not exposed on read, so paired-nutrition cleanup by
    // clientRecordId cannot be resolved here.
    // TODO(health-pkg): return paired hydration-nutrition clientRecordId.
    return null;
  }

  @override
  Future<String> writeBodyMeasurementEntry(
    BodyMeasurementWriteRequest request,
  ) async {
    final clientRecordId =
        'openvitals_body_${request.type.storageName.toLowerCase()}_${request.time.millisecondsSinceEpoch}_${_newId()}';
    final (type, value, unit) = switch (request.type) {
      BodyMeasurementType.weight => (
          HealthDataType.WEIGHT,
          request.value,
          HealthDataUnit.KILOGRAM,
        ),
      // domain stores centimetres; HEIGHT is written in metres.
      BodyMeasurementType.height => (
          HealthDataType.HEIGHT,
          request.value / 100.0,
          HealthDataUnit.METER,
        ),
      BodyMeasurementType.bodyFat => (
          HealthDataType.BODY_FAT_PERCENTAGE,
          request.value,
          HealthDataUnit.PERCENT,
        ),
    };
    await _catch(
      () => _health.writeHealthData(
        value: value,
        type: type,
        unit: unit,
        startTime: request.time,
        recordingMethod: RecordingMethod.manual,
        clientRecordId: clientRecordId,
      ),
      false,
    );
    return clientRecordId;
  }

  @override
  Future<String> writeVitalsMeasurementEntry(
    VitalsMeasurementWriteRequest request,
  ) async {
    final clientRecordId =
        'openvitals_vitals_${request.type.storageName.toLowerCase()}_${request.time.millisecondsSinceEpoch}_${_newId()}';
    switch (request.type) {
      case VitalsMeasurementType.bloodPressure:
        await _catch(
          () => _health.writeBloodPressure(
            systolic: request.value.round(),
            diastolic: (request.secondaryValue ?? 0).round(),
            startTime: request.time,
            recordingMethod: RecordingMethod.manual,
          ),
          false,
        );
      case VitalsMeasurementType.spo2:
        await _catch(
          () => _health.writeHealthData(
            value: request.value,
            type: HealthDataType.BLOOD_OXYGEN,
            unit: HealthDataUnit.PERCENT,
            startTime: request.time,
            recordingMethod: RecordingMethod.manual,
            clientRecordId: clientRecordId,
          ),
          false,
        );
      case VitalsMeasurementType.respiratoryRate:
        await _catch(
          () => _health.writeHealthData(
            value: request.value,
            type: HealthDataType.RESPIRATORY_RATE,
            unit: HealthDataUnit.RESPIRATIONS_PER_MINUTE,
            startTime: request.time,
            recordingMethod: RecordingMethod.manual,
            clientRecordId: clientRecordId,
          ),
          false,
        );
      case VitalsMeasurementType.bodyTemperature:
        await _catch(
          () => _health.writeHealthData(
            value: request.value,
            type: HealthDataType.BODY_TEMPERATURE,
            unit: HealthDataUnit.DEGREE_CELSIUS,
            startTime: request.time,
            recordingMethod: RecordingMethod.manual,
            clientRecordId: clientRecordId,
          ),
          false,
        );
    }
    return clientRecordId;
  }

  @override
  Future<String> writeNutritionEntry(NutritionWriteRequest request) async {
    final clientRecordId =
        'openvitals_nutrition_${request.time.millisecondsSinceEpoch}_${_newId()}';
    double? gram(NutritionNutrient nutrient) => request.nutrientValues[nutrient];
    await _catch(
      () => _health.writeMeal(
        mealType: MealType.UNKNOWN,
        startTime: request.time,
        endTime: request.time,
        name: request.name,
        clientRecordId: clientRecordId,
        caloriesConsumed: request.nutrientValues[NutritionNutrient.energy],
        carbohydrates: gram(NutritionNutrient.totalCarbohydrate),
        protein: gram(NutritionNutrient.protein),
        fatTotal: gram(NutritionNutrient.totalFat),
        fiber: gram(NutritionNutrient.dietaryFiber),
        sugar: gram(NutritionNutrient.sugar),
        caffeine: gram(NutritionNutrient.caffeine),
        recordingMethod: RecordingMethod.manual,
      ),
      false,
    );
    return clientRecordId;
  }

  @override
  Future<String?> deleteNutritionEntry(String id) async {
    await _catch(
      () => _health.deleteByUUID(uuid: id, type: HealthDataType.NUTRITION),
      false,
    );
    return id;
  }

  @override
  Future<String> writeActivityEntry(ActivityWriteRequest request) async {
    // TODO(health-pkg): writeWorkoutData does not accept a clientRecordId, so
    //   OpenVitals cannot stamp workouts; ownership on read falls back to the
    //   data-origin package name. The HealthWorkoutActivityType is recovered
    //   from the (placeholder) exerciseType index.
    final activityType = request.exerciseType >= 0 &&
            request.exerciseType < HealthWorkoutActivityType.values.length
        ? HealthWorkoutActivityType.values[request.exerciseType]
        : HealthWorkoutActivityType.OTHER;
    await _catch(
      () => _health.writeWorkoutData(
        activityType: activityType,
        start: request.startTime,
        end: request.endTime,
        totalEnergyBurned: (request.totalCaloriesKcal ?? request.activeCaloriesKcal)
            ?.round(),
        totalDistance: request.distanceMeters?.round(),
        title: request.title,
      ),
      false,
    );
    return 'openvitals_activity_${request.startTime.millisecondsSinceEpoch}_${_newId()}';
  }

  @override
  Future<void> deleteActivityEntry(String id) async {
    await _catch(
      () => _health.deleteByUUID(uuid: id, type: HealthDataType.WORKOUT),
      false,
    );
  }
}
