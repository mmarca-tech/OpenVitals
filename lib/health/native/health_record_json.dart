import '../../core/time/local_date.dart';
import '../../domain/model/activity_models.dart';
import '../../domain/model/body_models.dart';
import '../../domain/model/cycle_models.dart';
import '../../domain/model/heart_models.dart';
import '../../domain/model/mindfulness_models.dart';
import '../../domain/model/nutrition_models.dart';
import '../../domain/model/sleep_models.dart';
import '../../domain/model/vitals_models.dart';
import '../../features/imports/applehealth/apple_health_import_records.dart';

/// Health Connect `Metadata.RECORDING_METHOD_MANUAL_ENTRY`.
///
/// The native Kotlin `HealthRecordConverters.buildMetadata` treats any
/// recording method that is not `AUTOMATICALLY_RECORDED` (2) or
/// `ACTIVELY_RECORDED` (1) as a manual entry, so stamping `3` marks every
/// OpenVitals-authored / imported record as manually entered.
const int recordingMethodManual = 3;

/// Pure, device-free conversions between the canonical record-JSON schema
/// (documented in `packages/health_connect_native/lib/health_connect_native.dart`)
/// and the OpenVitals domain models.
///
/// This is the native replacement for the old `HealthConnectMappers` (which
/// mapped the `health` package's `HealthDataPoint`). Records now cross the
/// bridge as JSON objects (already `jsonDecode`-d into `Map<String, dynamic>`);
/// every key/unit here matches the Kotlin host converter exactly.
///
/// Ownership (Kotlin `isOpenVitalsRecord`) is inferred from
/// `dataOriginPackage == appPackageName`, and `clientRecordId` is now surfaced
/// on reads (the old `health`-package impl could not read it back).
class HealthRecordJson {
  const HealthRecordJson._();

  // ── Primitive accessors (JSON numbers may decode as int or double) ─────────

  static int? _int(Map<String, dynamic> m, String key) =>
      (m[key] as num?)?.toInt();

  static double? _double(Map<String, dynamic> m, String key) =>
      (m[key] as num?)?.toDouble();

  static String? _string(Map<String, dynamic> m, String key) =>
      m[key] as String?;

  static DateTime _instant(Map<String, dynamic> m, String key) =>
      DateTime.fromMillisecondsSinceEpoch((m[key] as num).toInt(), isUtc: true);

  static DateTime? _instantOrNull(Map<String, dynamic> m, String key) {
    final value = m[key];
    return value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((value as num).toInt(),
            isUtc: true);
  }

  static Duration? _zoneOffset(Map<String, dynamic> m, String key) {
    final value = m[key];
    return value == null ? null : Duration(seconds: (value as num).toInt());
  }

  static List<Map<String, dynamic>> _list(Map<String, dynamic> m, String key) {
    final raw = m[key];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return [for (final e in raw) (e as Map).cast<String, dynamic>()];
  }

  // ── Common metadata ────────────────────────────────────────────────────────

  /// The record's data-origin package name (used as `source`).
  static String source(Map<String, dynamic> m) =>
      _string(m, 'dataOriginPackage') ?? '';

  static String id(Map<String, dynamic> m) => _string(m, 'id') ?? '';

  static String? clientRecordId(Map<String, dynamic> m) =>
      _string(m, 'clientRecordId');

  /// Mirrors `isOpenVitalsRecord(sourcePackageName, appPackageName)`.
  static bool isOwned(Map<String, dynamic> m, String? appPackageName) =>
      appPackageName != null &&
      appPackageName.isNotEmpty &&
      _string(m, 'dataOriginPackage') == appPackageName;

  static int _durationMs(DateTime start, DateTime end) =>
      end.millisecondsSinceEpoch - start.millisecondsSinceEpoch;

  // ── Activity / workouts ─────────────────────────────────────────────────

  static ExerciseData exercise(Map<String, dynamic> m, String? appPackageName) {
    final start = _instant(m, 'startEpochMs');
    final end = _instant(m, 'endEpochMs');
    final segments = [
      for (final s in _list(m, 'segments'))
        ExerciseSegmentData(
          startTime: _instant(s, 'startEpochMs'),
          endTime: _instant(s, 'endEpochMs'),
          segmentType: _int(s, 'segmentType') ?? 0,
          repetitions: _int(s, 'repetitions') ?? 0,
        ),
    ];
    final laps = [
      for (final l in _list(m, 'laps'))
        ExerciseLapData(
          startTime: _instant(l, 'startEpochMs'),
          endTime: _instant(l, 'endEpochMs'),
          lengthMeters: _double(l, 'lengthMeters'),
        ),
    ];
    final routeObj = m['route'];
    final routePoints = <ExerciseRoutePoint>[
      if (routeObj is Map)
        for (final p in _list(routeObj.cast<String, dynamic>(), 'points'))
          ExerciseRoutePoint(
            time: _instant(p, 'timeEpochMs'),
            latitude: _double(p, 'latitude') ?? 0.0,
            longitude: _double(p, 'longitude') ?? 0.0,
            altitudeMeters: _double(p, 'altitudeMeters'),
            horizontalAccuracyMeters: _double(p, 'horizontalAccuracyMeters'),
            verticalAccuracyMeters: _double(p, 'verticalAccuracyMeters'),
          ),
    ];
    final route = routePoints.isEmpty
        ? const ExerciseRouteData()
        : ExerciseRouteData(
            status: ExerciseRouteStatus.data,
            points: routePoints,
          );
    return ExerciseData(
      id: id(m),
      title: _string(m, 'title'),
      // The native bridge carries the real Health Connect
      // `ExerciseSessionRecord.EXERCISE_TYPE_*` constant (the old `health`
      // package only had a placeholder enum index).
      exerciseType: _int(m, 'exerciseType') ?? 0,
      startTime: start,
      endTime: end,
      durationMs: _durationMs(start, end),
      source: source(m),
      notes: _string(m, 'notes'),
      startZoneOffset: _zoneOffset(m, 'startZoneOffsetSeconds'),
      endZoneOffset: _zoneOffset(m, 'endZoneOffsetSeconds'),
      lastModifiedTime: _instantOrNull(m, 'lastModifiedEpochMs'),
      clientRecordId: clientRecordId(m),
      clientRecordVersion: _int(m, 'clientRecordVersion'),
      recordingMethod: _int(m, 'recordingMethod'),
      device: _device(m),
      plannedExerciseSessionId: _string(m, 'plannedExerciseSessionId'),
      segments: segments,
      laps: laps,
      route: route,
      isOpenVitalsEntry: isOwned(m, appPackageName),
    );
  }

  static ExerciseDeviceData? _device(Map<String, dynamic> m) {
    final raw = m['device'];
    if (raw is! Map) return null;
    final device = raw.cast<String, dynamic>();
    return ExerciseDeviceData(
      type: _int(device, 'type') ?? 0,
      manufacturer: _string(device, 'manufacturer'),
      model: _string(device, 'model'),
    );
  }

  static List<SpeedSample> speedSamples(Map<String, dynamic> m) => [
        for (final s in _list(m, 'samples'))
          SpeedSample(
            time: _instant(s, 'timeEpochMs'),
            metersPerSecond: _double(s, 'metersPerSecond') ?? 0.0,
            source: source(m),
          ),
      ];

  // ── Heart ─────────────────────────────────────────────────────────────────

  static List<HeartRateSample> heartRateSamples(Map<String, dynamic> m) {
    final src = source(m);
    return [
      for (final s in _list(m, 'samples'))
        HeartRateSample(
          time: _instant(s, 'timeEpochMs'),
          beatsPerMinute: _int(s, 'bpm') ?? 0,
          source: src,
        ),
    ];
  }

  static RestingHeartRateSample restingHeartRateSample(
    Map<String, dynamic> m,
  ) =>
      RestingHeartRateSample(
        time: _instant(m, 'timeEpochMs'),
        beatsPerMinute: _int(m, 'bpm') ?? 0,
        source: source(m),
      );

  static HrvSample hrvSample(Map<String, dynamic> m) => HrvSample(
        time: _instant(m, 'timeEpochMs'),
        rmssdMs: _double(m, 'rmssdMs') ?? 0.0,
        source: source(m),
      );

  // ── Body ──────────────────────────────────────────────────────────────────

  static WeightEntry weightEntry(Map<String, dynamic> m, String? app) =>
      WeightEntry(
        time: _instant(m, 'timeEpochMs'),
        weightKg: _double(m, 'weightKg') ?? 0.0,
        source: source(m),
        id: id(m),
        isOpenVitalsEntry: isOwned(m, app),
      );

  static HeightEntry heightEntry(Map<String, dynamic> m, String? app) =>
      HeightEntry(
        time: _instant(m, 'timeEpochMs'),
        // HEIGHT is metres in the schema; the domain model stores centimetres.
        heightCm: (_double(m, 'heightMeters') ?? 0.0) * 100.0,
        source: source(m),
        id: id(m),
        isOpenVitalsEntry: isOwned(m, app),
      );

  static BodyFatEntry bodyFatEntry(Map<String, dynamic> m, String? app) =>
      BodyFatEntry(
        time: _instant(m, 'timeEpochMs'),
        percent: _double(m, 'percentage') ?? 0.0,
        source: source(m),
        id: id(m),
        isOpenVitalsEntry: isOwned(m, app),
      );

  static LeanBodyMassEntry leanBodyMassEntry(Map<String, dynamic> m) =>
      LeanBodyMassEntry(
        time: _instant(m, 'timeEpochMs'),
        massKg: _double(m, 'massKg') ?? 0.0,
        source: source(m),
      );

  static BmrEntry bmrEntry(Map<String, dynamic> m) => BmrEntry(
        time: _instant(m, 'timeEpochMs'),
        kcalPerDay: _double(m, 'kcalPerDay') ?? 0.0,
        source: source(m),
      );

  static BoneMassEntry boneMassEntry(Map<String, dynamic> m) => BoneMassEntry(
        time: _instant(m, 'timeEpochMs'),
        massKg: _double(m, 'massKg') ?? 0.0,
        source: source(m),
      );

  static BodyWaterMassEntry bodyWaterMassEntry(Map<String, dynamic> m) =>
      BodyWaterMassEntry(
        time: _instant(m, 'timeEpochMs'),
        massKg: _double(m, 'massKg') ?? 0.0,
        source: source(m),
      );

  // ── Vitals ────────────────────────────────────────────────────────────────

  static BloodPressureEntry bloodPressureEntry(
    Map<String, dynamic> m,
    String? app,
  ) =>
      BloodPressureEntry(
        time: _instant(m, 'timeEpochMs'),
        systolicMmHg: (_double(m, 'systolicMmHg') ?? 0.0).round(),
        diastolicMmHg: (_double(m, 'diastolicMmHg') ?? 0.0).round(),
        source: source(m),
        id: id(m),
        isOpenVitalsEntry: isOwned(m, app),
      );

  static SpO2Entry spO2Entry(Map<String, dynamic> m, String? app) => SpO2Entry(
        time: _instant(m, 'timeEpochMs'),
        percent: _double(m, 'percentage') ?? 0.0,
        source: source(m),
        id: id(m),
        isOpenVitalsEntry: isOwned(m, app),
      );

  static RespiratoryRateEntry respiratoryRateEntry(
    Map<String, dynamic> m,
    String? app,
  ) =>
      RespiratoryRateEntry(
        time: _instant(m, 'timeEpochMs'),
        breathsPerMinute: _double(m, 'rate') ?? 0.0,
        source: source(m),
        id: id(m),
        isOpenVitalsEntry: isOwned(m, app),
      );

  static BodyTempEntry bodyTempEntry(Map<String, dynamic> m, String? app) =>
      BodyTempEntry(
        time: _instant(m, 'timeEpochMs'),
        temperatureCelsius: _double(m, 'temperatureCelsius') ?? 0.0,
        source: source(m),
        id: id(m),
        isOpenVitalsEntry: isOwned(m, app),
      );

  static BloodGlucoseEntry bloodGlucoseEntry(Map<String, dynamic> m) =>
      BloodGlucoseEntry(
        time: _instant(m, 'timeEpochMs'),
        millimolesPerLiter: _double(m, 'levelMmolL') ?? 0.0,
        specimenSource: _int(m, 'specimenSource') ?? 0,
        mealType: _int(m, 'mealType') ?? 0,
        relationToMeal: _int(m, 'relationToMeal') ?? 0,
        source: source(m),
      );

  static Vo2MaxEntry vo2MaxEntry(Map<String, dynamic> m) => Vo2MaxEntry(
        time: _instant(m, 'timeEpochMs'),
        vo2MaxMlPerKgPerMin:
            _double(m, 'vo2MillilitersPerMinuteKilogram') ?? 0.0,
        source: source(m),
      );

  static SkinTemperatureEntry skinTemperatureEntry(Map<String, dynamic> m) {
    final deltas = [
      for (final d in _list(m, 'deltas')) _double(d, 'deltaCelsius') ?? 0.0,
    ];
    double? avg;
    double? min;
    double? max;
    if (deltas.isNotEmpty) {
      avg = deltas.reduce((a, b) => a + b) / deltas.length;
      min = deltas.reduce((a, b) => a < b ? a : b);
      max = deltas.reduce((a, b) => a > b ? a : b);
    }
    return SkinTemperatureEntry(
      startTime: _instant(m, 'startEpochMs'),
      endTime: _instant(m, 'endEpochMs'),
      baselineCelsius: _double(m, 'baselineCelsius'),
      averageDeltaCelsius: avg,
      minDeltaCelsius: min,
      maxDeltaCelsius: max,
      measurementLocation: _int(m, 'measurementLocation') ?? 0,
      source: source(m),
    );
  }

  // ── Nutrition / hydration ─────────────────────────────────────────────────

  static NutritionEntry nutritionEntry(Map<String, dynamic> m, String? app) {
    final nutrientValues = <NutritionNutrient, double>{};
    final energyKcal = _double(m, 'energyKcal');
    if (energyKcal != null && energyKcal > 0) {
      nutrientValues[NutritionNutrient.energy] = energyKcal;
    }
    for (final entry in _nutrientJsonKeys.entries) {
      final nutrient = entry.key;
      if (nutrient == NutritionNutrient.energy) continue;
      final grams = _double(m, entry.value);
      if (grams != null && grams > 0) nutrientValues[nutrient] = grams;
    }
    double? nutrient(NutritionNutrient n) => nutrientValues[n];
    return NutritionEntry(
      time: _instant(m, 'startEpochMs'),
      endTime: _instant(m, 'endEpochMs'),
      mealType: _int(m, 'mealType') ?? 0,
      name: _string(m, 'name'),
      energyKcal: energyKcal,
      proteinGrams: nutrient(NutritionNutrient.protein),
      carbsGrams: nutrient(NutritionNutrient.totalCarbohydrate),
      fatGrams: nutrient(NutritionNutrient.totalFat),
      fiberGrams: nutrient(NutritionNutrient.dietaryFiber),
      sugarGrams: nutrient(NutritionNutrient.sugar),
      source: source(m),
      nutrientValues: nutrientValues,
      id: id(m),
      clientRecordId: clientRecordId(m),
      isOpenVitalsEntry: isOwned(m, app),
    );
  }

  static HydrationEntry hydrationEntry(Map<String, dynamic> m, String? app) =>
      HydrationEntry(
        startTime: _instant(m, 'startEpochMs'),
        endTime: _instant(m, 'endEpochMs'),
        liters: _double(m, 'volumeLiters') ?? 0.0,
        source: source(m),
        id: id(m),
        clientRecordId: clientRecordId(m),
        isOpenVitalsEntry: isOwned(m, app),
      );

  // ── Mindfulness ─────────────────────────────────────────────────────────

  static MindfulnessSession mindfulnessSession(
    Map<String, dynamic> m,
    String? app,
  ) {
    final start = _instant(m, 'startEpochMs');
    final end = _instant(m, 'endEpochMs');
    return MindfulnessSession(
      id: id(m),
      title: _string(m, 'title'),
      startTime: start,
      endTime: end,
      durationMs: _durationMs(start, end),
      source: source(m),
      isOpenVitalsEntry: isOwned(m, app),
    );
  }

  // ── Sleep ─────────────────────────────────────────────────────────────────

  static SleepData sleepData(Map<String, dynamic> m) {
    final start = _instant(m, 'startEpochMs');
    final end = _instant(m, 'endEpochMs');
    final stages = [
      for (final s in _list(m, 'stages'))
        SleepStage(
          startTime: _instant(s, 'startEpochMs'),
          endTime: _instant(s, 'endEpochMs'),
          stageType: _int(s, 'stage') ?? 0,
        ),
    ]..sort((a, b) => a.startTime.compareTo(b.startTime));
    return SleepData(
      id: id(m),
      startTime: start,
      endTime: end,
      durationMs: _durationMs(start, end),
      source: source(m),
      title: _string(m, 'title'),
      notes: _string(m, 'notes'),
      startZoneOffset: _zoneOffset(m, 'startZoneOffsetSeconds'),
      endZoneOffset: _zoneOffset(m, 'endZoneOffsetSeconds'),
      lastModifiedTime: _instantOrNull(m, 'lastModifiedEpochMs'),
      clientRecordId: clientRecordId(m),
      clientRecordVersion: _int(m, 'clientRecordVersion'),
      recordingMethod: _int(m, 'recordingMethod'),
      device: _sleepDevice(m),
      stages: stages,
    );
  }

  static SleepDeviceData? _sleepDevice(Map<String, dynamic> m) {
    final raw = m['device'];
    if (raw is! Map) return null;
    final device = raw.cast<String, dynamic>();
    return SleepDeviceData(
      type: _int(device, 'type') ?? 0,
      manufacturer: _string(device, 'manufacturer'),
      model: _string(device, 'model'),
    );
  }

  // ── Cycle ───────────────────────────────────────────────────────────────

  static MenstruationFlowEntry menstruationFlowEntry(Map<String, dynamic> m) =>
      MenstruationFlowEntry(
        time: _instant(m, 'timeEpochMs'),
        flow: _int(m, 'flow') ?? 0,
        source: source(m),
      );

  static MenstruationPeriodEntry menstruationPeriodEntry(
    Map<String, dynamic> m,
  ) =>
      MenstruationPeriodEntry(
        startTime: _instant(m, 'startEpochMs'),
        endTime: _instant(m, 'endEpochMs'),
        source: source(m),
      );

  static OvulationTestEntry ovulationTestEntry(Map<String, dynamic> m) =>
      OvulationTestEntry(
        time: _instant(m, 'timeEpochMs'),
        result: _int(m, 'result') ?? 0,
        source: source(m),
      );

  static CervicalMucusEntry cervicalMucusEntry(Map<String, dynamic> m) =>
      CervicalMucusEntry(
        time: _instant(m, 'timeEpochMs'),
        appearance: _int(m, 'appearance') ?? 0,
        sensation: _int(m, 'sensation') ?? 0,
        source: source(m),
      );

  static BasalBodyTemperatureEntry basalBodyTemperatureEntry(
    Map<String, dynamic> m,
  ) =>
      BasalBodyTemperatureEntry(
        time: _instant(m, 'timeEpochMs'),
        temperatureCelsius: _double(m, 'temperatureCelsius') ?? 0.0,
        measurementLocation: _int(m, 'measurementLocation') ?? 0,
        source: source(m),
      );

  static IntermenstrualBleedingEntry intermenstrualBleedingEntry(
    Map<String, dynamic> m,
  ) =>
      IntermenstrualBleedingEntry(
        time: _instant(m, 'timeEpochMs'),
        source: source(m),
      );

  static SexualActivityEntry sexualActivityEntry(Map<String, dynamic> m) =>
      SexualActivityEntry(
        time: _instant(m, 'timeEpochMs'),
        protectionUsed: _int(m, 'protectionUsed') ?? 0,
        source: source(m),
      );

  // ── Daily-aggregation helpers (device-independent, pure) ──────────────────

  static List<HeartRateSummary> dailyHeartRateSummaries(
    List<HeartRateSample> samples,
  ) {
    final byDate = <LocalDate, List<int>>{};
    for (final sample in samples) {
      final date = LocalDate.fromDateTime(sample.time.toLocal());
      (byDate[date] ??= <int>[]).add(sample.beatsPerMinute);
    }
    final result = <HeartRateSummary>[];
    final dates = byDate.keys.toList()..sort();
    for (final date in dates) {
      final bpms = byDate[date]!;
      final sum = bpms.fold<int>(0, (a, b) => a + b);
      result.add(
        HeartRateSummary(
          date: date,
          avgBpm: (sum / bpms.length).round(),
          minBpm: bpms.reduce((a, b) => a < b ? a : b),
          maxBpm: bpms.reduce((a, b) => a > b ? a : b),
        ),
      );
    }
    return result;
  }

  static List<DailyRestingHR> dailyRestingHR(
    List<RestingHeartRateSample> samples,
  ) {
    final byDate = <LocalDate, List<int>>{};
    for (final sample in samples) {
      final date = LocalDate.fromDateTime(sample.time.toLocal());
      (byDate[date] ??= <int>[]).add(sample.beatsPerMinute);
    }
    final dates = byDate.keys.toList()..sort();
    return [
      for (final date in dates)
        DailyRestingHR(
          date: date,
          bpm: (byDate[date]!.fold<int>(0, (a, b) => a + b) /
                  byDate[date]!.length)
              .round(),
        ),
    ];
  }

  static List<DailyHrv> dailyHrv(List<HrvSample> samples) {
    final byDate = <LocalDate, List<double>>{};
    for (final sample in samples) {
      final date = LocalDate.fromDateTime(sample.time.toLocal());
      (byDate[date] ??= <double>[]).add(sample.rmssdMs);
    }
    final dates = byDate.keys.toList()..sort();
    return [
      for (final date in dates)
        DailyHrv(
          date: date,
          rmssdMs: byDate[date]!.fold<double>(0, (a, b) => a + b) /
              byDate[date]!.length,
        ),
    ];
  }

  // ── Write builders (domain → JSON map) ────────────────────────────────────

  static Map<String, dynamic> intervalRecord(
    String recordType,
    DateTime start,
    DateTime end,
    String? clientRecordId, {
    Map<String, dynamic> fields = const <String, dynamic>{},
  }) =>
      <String, dynamic>{
        'recordType': recordType,
        'startEpochMs': start.millisecondsSinceEpoch,
        'endEpochMs': end.millisecondsSinceEpoch,
        'recordingMethod': recordingMethodManual,
        'clientRecordId': ?clientRecordId,
        ...fields,
      };

  static Map<String, dynamic> instantRecord(
    String recordType,
    DateTime time,
    String? clientRecordId, {
    Map<String, dynamic> fields = const <String, dynamic>{},
  }) =>
      <String, dynamic>{
        'recordType': recordType,
        'timeEpochMs': time.millisecondsSinceEpoch,
        'recordingMethod': recordingMethodManual,
        'clientRecordId': ?clientRecordId,
        ...fields,
      };

  /// Builds the Nutrition record JSON for a manual [NutritionWriteRequest]-style
  /// nutrient map (energy in kcal, everything else in grams).
  static Map<String, dynamic> nutritionRecord({
    required DateTime time,
    required String? name,
    required Map<NutritionNutrient, double> nutrientValues,
    required String clientRecordId,
    int mealType = 0,
  }) {
    final fields = <String, dynamic>{
      'mealType': mealType,
      'name': ?name,
    };
    nutrientValues.forEach((nutrient, value) {
      final key = _nutrientJsonKeys[nutrient];
      if (key != null) fields[key] = value;
    });
    return intervalRecord('Nutrition', time, time, clientRecordId,
        fields: fields);
  }

  // ── Apple Health import (ImportRecord → JSON map) ──────────────────────────

  /// Converts one converted [ImportRecord] into its canonical record JSON,
  /// carrying its deterministic `apple_health_`-prefixed clientRecordId. Every
  /// import record type is supported by the native bridge (the old
  /// `health`-package impl silently dropped many of them).
  static Map<String, dynamic> importRecord(ImportRecord record) {
    Map<String, dynamic> interval(
      String recordType,
      DateTime start,
      Duration? startZone,
      DateTime end,
      Duration? endZone,
      Map<String, dynamic> fields,
    ) {
      final map = <String, dynamic>{
        'recordType': recordType,
        'startEpochMs': start.millisecondsSinceEpoch,
        'endEpochMs': end.millisecondsSinceEpoch,
        'recordingMethod': recordingMethodManual,
        'clientRecordId': record.clientRecordId,
        ...fields,
      };
      if (startZone != null) map['startZoneOffsetSeconds'] = startZone.inSeconds;
      if (endZone != null) map['endZoneOffsetSeconds'] = endZone.inSeconds;
      return map;
    }

    Map<String, dynamic> instant(
      String recordType,
      DateTime time,
      Duration? zone,
      Map<String, dynamic> fields,
    ) {
      final map = <String, dynamic>{
        'recordType': recordType,
        'timeEpochMs': time.millisecondsSinceEpoch,
        'recordingMethod': recordingMethodManual,
        'clientRecordId': record.clientRecordId,
        ...fields,
      };
      if (zone != null) map['zoneOffsetSeconds'] = zone.inSeconds;
      return map;
    }

    switch (record) {
      case StepsImportRecord r:
        return interval('Steps', r.startTime, r.startZoneOffset, r.endTime,
            r.endZoneOffset, {'count': r.count});
      case DistanceImportRecord r:
        return interval('Distance', r.startTime, r.startZoneOffset, r.endTime,
            r.endZoneOffset, {'distanceMeters': r.meters});
      case ActiveCaloriesBurnedImportRecord r:
        return interval('ActiveCaloriesBurned', r.startTime, r.startZoneOffset,
            r.endTime, r.endZoneOffset, {'energyKcal': r.kilocalories});
      case BasalMetabolicRateImportRecord r:
        return instant('BasalMetabolicRate', r.time, r.zoneOffset,
            {'kcalPerDay': r.kilocaloriesPerDay});
      case FloorsClimbedImportRecord r:
        return interval('FloorsClimbed', r.startTime, r.startZoneOffset,
            r.endTime, r.endZoneOffset, {'floors': r.floors});
      case ElevationGainedImportRecord r:
        return interval('ElevationGained', r.startTime, r.startZoneOffset,
            r.endTime, r.endZoneOffset, {'elevationMeters': r.meters});
      case WheelchairPushesImportRecord r:
        return interval('WheelchairPushes', r.startTime, r.startZoneOffset,
            r.endTime, r.endZoneOffset, {'count': r.count});
      case SpeedImportRecord r:
        return interval('Speed', r.startTime, r.startZoneOffset, r.endTime,
            r.endZoneOffset, {
          'samples': [
            for (final s in r.samples)
              {
                'timeEpochMs': s.time.millisecondsSinceEpoch,
                'metersPerSecond': s.metersPerSecond,
              },
          ],
        });
      case HeartRateImportRecord r:
        return interval('HeartRate', r.startTime, r.startZoneOffset, r.endTime,
            r.endZoneOffset, {
          'samples': [
            for (final s in r.samples)
              {
                'timeEpochMs': s.time.millisecondsSinceEpoch,
                'bpm': s.beatsPerMinute,
              },
          ],
        });
      case RestingHeartRateImportRecord r:
        return instant('RestingHeartRate', r.time, r.zoneOffset,
            {'bpm': r.beatsPerMinute});
      case WeightImportRecord r:
        return instant(
            'Weight', r.time, r.zoneOffset, {'weightKg': r.kilograms});
      case HeightImportRecord r:
        return instant(
            'Height', r.time, r.zoneOffset, {'heightMeters': r.meters});
      case BodyFatImportRecord r:
        return instant(
            'BodyFat', r.time, r.zoneOffset, {'percentage': r.percent});
      case LeanBodyMassImportRecord r:
        return instant(
            'LeanBodyMass', r.time, r.zoneOffset, {'massKg': r.kilograms});
      case BoneMassImportRecord r:
        return instant(
            'BoneMass', r.time, r.zoneOffset, {'massKg': r.kilograms});
      case BodyWaterMassImportRecord r:
        return instant(
            'BodyWaterMass', r.time, r.zoneOffset, {'massKg': r.kilograms});
      case HydrationImportRecord r:
        return interval('Hydration', r.startTime, r.startZoneOffset, r.endTime,
            r.endZoneOffset, {'volumeLiters': r.milliliters / 1000.0});
      case OxygenSaturationImportRecord r:
        return instant('OxygenSaturation', r.time, r.zoneOffset,
            {'percentage': r.percent});
      case RespiratoryRateImportRecord r:
        return instant(
            'RespiratoryRate', r.time, r.zoneOffset, {'rate': r.rate});
      case BodyTemperatureImportRecord r:
        return instant('BodyTemperature', r.time, r.zoneOffset,
            {'temperatureCelsius': r.celsius});
      case BasalBodyTemperatureImportRecord r:
        return instant('BasalBodyTemperature', r.time, r.zoneOffset,
            {'temperatureCelsius': r.celsius});
      case BloodGlucoseImportRecord r:
        return instant('BloodGlucose', r.time, r.zoneOffset,
            {'levelMmolL': r.millimolesPerLiter});
      case Vo2MaxImportRecord r:
        return instant('Vo2Max', r.time, r.zoneOffset,
            {'vo2MillilitersPerMinuteKilogram': r.vo2MillilitersPerMinuteKilogram});
      case BloodPressureImportRecord r:
        return instant('BloodPressure', r.time, r.zoneOffset, {
          'systolicMmHg': r.systolicMmHg,
          'diastolicMmHg': r.diastolicMmHg,
        });
      case SleepSessionImportRecord r:
        return interval('Sleep', r.startTime, r.startZoneOffset, r.endTime,
            r.endZoneOffset, {
          'title': r.title,
          'stages': [
            for (final s in r.stages)
              {
                'startEpochMs': s.startTime.millisecondsSinceEpoch,
                'endEpochMs': s.endTime.millisecondsSinceEpoch,
                'stage': _importSleepStage[s.stage] ?? 0,
              },
          ],
        });
      case NutritionImportRecord r:
        final fields = <String, dynamic>{
          if (r.name != null) 'name': r.name,
          if (r.energyKilocalories != null)
            'energyKcal': r.energyKilocalories,
        };
        r.nutrientGrams.forEach((key, value) {
          fields[key] = value;
        });
        return interval('Nutrition', r.startTime, r.startZoneOffset, r.endTime,
            r.endZoneOffset, fields);
      case ExerciseSessionImportRecord r:
        final fields = <String, dynamic>{
          'exerciseType': _importExerciseType[r.exerciseType] ?? 0,
          'title': r.title,
        };
        final route = r.route;
        if (route != null && route.route.isNotEmpty) {
          fields['route'] = {
            'points': [
              for (final p in route.route)
                {
                  'timeEpochMs': p.time.millisecondsSinceEpoch,
                  'latitude': p.latitude,
                  'longitude': p.longitude,
                  if (p.altitudeMeters != null)
                    'altitudeMeters': p.altitudeMeters,
                  if (p.horizontalAccuracyMeters != null)
                    'horizontalAccuracyMeters': p.horizontalAccuracyMeters,
                  if (p.verticalAccuracyMeters != null)
                    'verticalAccuracyMeters': p.verticalAccuracyMeters,
                },
            ],
          };
        }
        return interval('ExerciseSession', r.startTime, r.startZoneOffset,
            r.endTime, r.endZoneOffset, fields);
      case MindfulnessSessionImportRecord r:
        return interval('MindfulnessSession', r.startTime, r.startZoneOffset,
            r.endTime, r.endZoneOffset, {'title': r.title});
      case MenstruationFlowImportRecord r:
        return instant('MenstruationFlow', r.time, r.zoneOffset,
            {'flow': r.flow.index});
      case OvulationTestImportRecord r:
        return instant('OvulationTest', r.time, r.zoneOffset,
            {'result': _importOvulationResult[r.result] ?? 0});
      case CervicalMucusImportRecord r:
        return instant('CervicalMucus', r.time, r.zoneOffset, {
          'appearance': r.appearance.index,
          'sensation': r.sensation.index,
        });
      case IntermenstrualBleedingImportRecord r:
        return instant(
            'IntermenstrualBleeding', r.time, r.zoneOffset, const {});
      case SexualActivityImportRecord r:
        return instant('SexualActivity', r.time, r.zoneOffset,
            {'protectionUsed': r.protectionUsed.index});
    }
  }

  /// The schema record-type string for an [ImportRecord.targetType] (an
  /// AndroidX record class name), for `filterExistingClientIds`.
  static String? schemaTypeForImport(String targetType) {
    if (targetType == 'SleepSessionRecord') return 'Sleep';
    if (targetType.endsWith('Record')) {
      return targetType.substring(0, targetType.length - 'Record'.length);
    }
    return null;
  }

  // ── Lookup tables ──────────────────────────────────────────────────────────

  /// Domain nutrient → canonical JSON key (energy carried as kcal, everything
  /// else in grams). `dietaryFiber` uses the schema's `fiber` alias.
  static const Map<NutritionNutrient, String> _nutrientJsonKeys = {
    NutritionNutrient.energy: 'energyKcal',
    NutritionNutrient.energyFromFat: 'energyFromFatKcal',
    NutritionNutrient.protein: 'protein',
    NutritionNutrient.totalCarbohydrate: 'totalCarbohydrate',
    NutritionNutrient.totalFat: 'totalFat',
    NutritionNutrient.dietaryFiber: 'fiber',
    NutritionNutrient.sugar: 'sugar',
    NutritionNutrient.saturatedFat: 'saturatedFat',
    NutritionNutrient.monounsaturatedFat: 'monounsaturatedFat',
    NutritionNutrient.polyunsaturatedFat: 'polyunsaturatedFat',
    NutritionNutrient.transFat: 'transFat',
    NutritionNutrient.unsaturatedFat: 'unsaturatedFat',
    NutritionNutrient.cholesterol: 'cholesterol',
    NutritionNutrient.sodium: 'sodium',
    NutritionNutrient.potassium: 'potassium',
    NutritionNutrient.calcium: 'calcium',
    NutritionNutrient.iron: 'iron',
    NutritionNutrient.biotin: 'biotin',
    NutritionNutrient.folate: 'folate',
    NutritionNutrient.folicAcid: 'folicAcid',
    NutritionNutrient.niacin: 'niacin',
    NutritionNutrient.pantothenicAcid: 'pantothenicAcid',
    NutritionNutrient.riboflavin: 'riboflavin',
    NutritionNutrient.thiamin: 'thiamin',
    NutritionNutrient.vitaminA: 'vitaminA',
    NutritionNutrient.vitaminB12: 'vitaminB12',
    NutritionNutrient.vitaminB6: 'vitaminB6',
    NutritionNutrient.vitaminC: 'vitaminC',
    NutritionNutrient.vitaminD: 'vitaminD',
    NutritionNutrient.vitaminE: 'vitaminE',
    NutritionNutrient.vitaminK: 'vitaminK',
    NutritionNutrient.chloride: 'chloride',
    NutritionNutrient.chromium: 'chromium',
    NutritionNutrient.copper: 'copper',
    NutritionNutrient.iodine: 'iodine',
    NutritionNutrient.magnesium: 'magnesium',
    NutritionNutrient.manganese: 'manganese',
    NutritionNutrient.molybdenum: 'molybdenum',
    NutritionNutrient.phosphorus: 'phosphorus',
    NutritionNutrient.selenium: 'selenium',
    NutritionNutrient.zinc: 'zinc',
    NutritionNutrient.caffeine: 'caffeine',
  };

  /// [SleepStageType] → Health Connect `SleepSessionRecord.STAGE_TYPE_*`.
  static const Map<SleepStageType, int> _importSleepStage = {
    SleepStageType.awake: 1,
    SleepStageType.sleeping: 2,
    SleepStageType.light: 4,
    SleepStageType.deep: 5,
    SleepStageType.rem: 6,
    SleepStageType.awakeInBed: 7,
  };

  /// [OvulationResultType] → `OvulationTestRecord.RESULT_*`.
  static const Map<OvulationResultType, int> _importOvulationResult = {
    OvulationResultType.inconclusive: 0,
    OvulationResultType.positive: 1,
    OvulationResultType.high: 2,
    OvulationResultType.negative: 3,
  };

  /// [ImportExerciseType] → `ExerciseSessionRecord.EXERCISE_TYPE_*`.
  static const Map<ImportExerciseType, int> _importExerciseType = {
    ImportExerciseType.running: 56,
    ImportExerciseType.biking: 8,
    ImportExerciseType.walking: 79,
    ImportExerciseType.hiking: 37,
    ImportExerciseType.wheelchair: 82,
    ImportExerciseType.rowing: 53,
    ImportExerciseType.paddling: 46,
    ImportExerciseType.skiing: 61,
    ImportExerciseType.snowboarding: 62,
    ImportExerciseType.snowshoeing: 63,
    ImportExerciseType.skating: 60,
    ImportExerciseType.sailing: 58,
    ImportExerciseType.surfing: 72,
    ImportExerciseType.swimmingOpenWater: 73,
    ImportExerciseType.golf: 32,
    ImportExerciseType.yoga: 83,
    ImportExerciseType.pilates: 48,
    ImportExerciseType.elliptical: 25,
    ImportExerciseType.strengthTraining: 70,
    ImportExerciseType.stairClimbing: 68,
    ImportExerciseType.otherWorkout: 0,
  };
}
