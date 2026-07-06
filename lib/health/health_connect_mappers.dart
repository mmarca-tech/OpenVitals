import 'package:health/health.dart';

import '../core/time/local_date.dart';
import '../domain/model/body_models.dart';
import '../domain/model/cycle_models.dart';
import '../domain/model/heart_models.dart';
import '../domain/model/mindfulness_models.dart';
import '../domain/model/nutrition_models.dart';
import '../domain/model/sleep_models.dart';
import '../domain/model/vitals_models.dart';
import '../domain/model/activity_models.dart';

/// Port of the Kotlin `HealthConnectMappers` + the inline record→domain mapping
/// the per-metric readers do.
///
/// The Dart `health` package models every read as a [HealthDataPoint]. On
/// Android the plugin sets `sourceName` to the record's data-origin package
/// name and `uuid` to the record id; it does NOT surface `clientRecordId` on
/// reads.
///
/// Ownership (the Kotlin `isOpenVitalsRecord`) is therefore inferred from the
/// data-origin package name equalling the app's own package name — the same
/// semantics as the Kotlin source (`metadata.dataOrigin.packageName ==
/// appPackageName`).
///
// TODO(health-pkg): clientRecordId is not exposed on reads, so mapped entries
//   carry `clientRecordId: null`. OpenVitals still STAMPS a namespaced
//   clientRecordId on every write (see [HealthDataSource]); ownership on
//   read/edit falls back to package-name equality.
class HealthConnectMappers {
  const HealthConnectMappers._();

  /// The record's data-origin package name (Android) — used as `source`.
  static String sourceOf(HealthDataPoint point) => point.sourceName;

  /// Mirrors `isOpenVitalsRecord(sourcePackageName, appPackageName)`.
  static bool isOpenVitalsRecord(HealthDataPoint point, String? appPackageName) =>
      appPackageName != null &&
      appPackageName.isNotEmpty &&
      point.sourceName == appPackageName;

  /// Extracts the scalar value of a numeric data point (0 if not numeric).
  static num numericValue(HealthDataPoint point) {
    final value = point.value;
    return value is NumericHealthValue ? value.numericValue : 0;
  }

  static int durationMs(HealthDataPoint point) =>
      point.dateTo.millisecondsSinceEpoch - point.dateFrom.millisecondsSinceEpoch;

  // ── Heart ─────────────────────────────────────────────────────────────────

  static HeartRateSample heartRateSample(HealthDataPoint point) => HeartRateSample(
        time: point.dateFrom.toUtc(),
        beatsPerMinute: numericValue(point).round(),
        source: sourceOf(point),
      );

  static RestingHeartRateSample restingHeartRateSample(HealthDataPoint point) =>
      RestingHeartRateSample(
        time: point.dateFrom.toUtc(),
        beatsPerMinute: numericValue(point).round(),
        source: sourceOf(point),
      );

  static HrvSample hrvSample(HealthDataPoint point) => HrvSample(
        time: point.dateFrom.toUtc(),
        rmssdMs: numericValue(point).toDouble(),
        source: sourceOf(point),
      );

  // ── Body ──────────────────────────────────────────────────────────────────

  static WeightEntry weightEntry(HealthDataPoint point, String? appPackageName) =>
      WeightEntry(
        time: point.dateFrom.toUtc(),
        weightKg: numericValue(point).toDouble(),
        source: sourceOf(point),
        id: point.uuid,
        isOpenVitalsEntry: isOpenVitalsRecord(point, appPackageName),
      );

  static HeightEntry heightEntry(HealthDataPoint point, String? appPackageName) =>
      HeightEntry(
        time: point.dateFrom.toUtc(),
        // HEIGHT is reported in METER; the domain model stores centimetres.
        heightCm: numericValue(point).toDouble() * 100.0,
        source: sourceOf(point),
        id: point.uuid,
        isOpenVitalsEntry: isOpenVitalsRecord(point, appPackageName),
      );

  static BodyFatEntry bodyFatEntry(HealthDataPoint point, String? appPackageName) =>
      BodyFatEntry(
        time: point.dateFrom.toUtc(),
        percent: numericValue(point).toDouble(),
        source: sourceOf(point),
        id: point.uuid,
        isOpenVitalsEntry: isOpenVitalsRecord(point, appPackageName),
      );

  static LeanBodyMassEntry leanBodyMassEntry(HealthDataPoint point) =>
      LeanBodyMassEntry(
        time: point.dateFrom.toUtc(),
        massKg: numericValue(point).toDouble(),
        source: sourceOf(point),
      );

  static BmrEntry bmrEntry(HealthDataPoint point) => BmrEntry(
        time: point.dateFrom.toUtc(),
        // BasalMetabolicRateRecord is surfaced as BASAL_ENERGY_BURNED in
        // kilocalories/day.
        kcalPerDay: numericValue(point).toDouble(),
        source: sourceOf(point),
      );

  static BodyWaterMassEntry bodyWaterMassEntry(HealthDataPoint point) =>
      BodyWaterMassEntry(
        time: point.dateFrom.toUtc(),
        massKg: numericValue(point).toDouble(),
        source: sourceOf(point),
      );

  // ── Vitals ──────────────────────────────────────────────────────────────

  static SpO2Entry spO2Entry(HealthDataPoint point, String? appPackageName) =>
      SpO2Entry(
        time: point.dateFrom.toUtc(),
        percent: numericValue(point).toDouble(),
        source: sourceOf(point),
        id: point.uuid,
        isOpenVitalsEntry: isOpenVitalsRecord(point, appPackageName),
      );

  static RespiratoryRateEntry respiratoryRateEntry(
    HealthDataPoint point,
    String? appPackageName,
  ) =>
      RespiratoryRateEntry(
        time: point.dateFrom.toUtc(),
        breathsPerMinute: numericValue(point).toDouble(),
        source: sourceOf(point),
        id: point.uuid,
        isOpenVitalsEntry: isOpenVitalsRecord(point, appPackageName),
      );

  static BodyTempEntry bodyTempEntry(
    HealthDataPoint point,
    String? appPackageName,
  ) =>
      BodyTempEntry(
        time: point.dateFrom.toUtc(),
        temperatureCelsius: numericValue(point).toDouble(),
        source: sourceOf(point),
        id: point.uuid,
        isOpenVitalsEntry: isOpenVitalsRecord(point, appPackageName),
      );

  static BloodGlucoseEntry bloodGlucoseEntry(HealthDataPoint point) =>
      BloodGlucoseEntry(
        time: point.dateFrom.toUtc(),
        millimolesPerLiter: numericValue(point).toDouble(),
        // specimenSource / mealType / relationToMeal are not exposed by the
        // health package read model.
        // TODO(health-pkg): metadata (specimen source, meal relation) unknown.
        specimenSource: 0,
        mealType: 0,
        relationToMeal: 0,
        source: sourceOf(point),
      );

  static SkinTemperatureEntry skinTemperatureEntry(HealthDataPoint point) {
    final value = point.value;
    double? baseline;
    double? delta;
    if (value is SkinTemperatureHealthValue) {
      baseline = value.baseline;
      delta = value.temperatureDelta;
    }
    return SkinTemperatureEntry(
      startTime: point.dateFrom.toUtc(),
      endTime: point.dateTo.toUtc(),
      baselineCelsius: baseline,
      averageDeltaCelsius: delta,
      // The health package only exposes an average delta, not min/max.
      // TODO(health-pkg): min/max skin-temperature delta unavailable.
      minDeltaCelsius: delta,
      maxDeltaCelsius: delta,
      measurementLocation: 0,
      source: sourceOf(point),
    );
  }

  // ── Cycle ───────────────────────────────────────────────────────────────

  static MenstruationFlowEntry menstruationFlowEntry(HealthDataPoint point) {
    final value = point.value;
    final flow = value is MenstruationFlowHealthValue
        ? (value.flow?.index ?? 0)
        : numericValue(point).toInt();
    return MenstruationFlowEntry(
      time: point.dateFrom.toUtc(),
      flow: flow,
      source: sourceOf(point),
    );
  }

  // ── Mindfulness ───────────────────────────────────────────────────────────

  static MindfulnessSession mindfulnessSession(
    HealthDataPoint point,
    String? appPackageName,
  ) =>
      MindfulnessSession(
        id: point.uuid,
        title: null,
        startTime: point.dateFrom.toUtc(),
        endTime: point.dateTo.toUtc(),
        durationMs: durationMs(point),
        source: sourceOf(point),
        isOpenVitalsEntry: isOpenVitalsRecord(point, appPackageName),
      );

  // ── Sleep ─────────────────────────────────────────────────────────────────

  /// Maps a single SLEEP_SESSION data point.
  ///
  // TODO(health-pkg): per-stage breakdown is delivered as separate SLEEP_*
  //   data points rather than nested inside the session; [stages] cannot be
  //   reconstructed from a single point, so only the session span/duration is
  //   populated here. [HealthDataSource.readSleepData] fills durations via the
  //   session span.
  static SleepData sleepData(HealthDataPoint point) => SleepData(
        id: point.uuid,
        startTime: point.dateFrom.toUtc(),
        endTime: point.dateTo.toUtc(),
        durationMs: durationMs(point),
        source: sourceOf(point),
      );

  // ── Activity / workouts ─────────────────────────────────────────────────

  static ExerciseData exerciseData(
    HealthDataPoint point,
    String? appPackageName,
  ) {
    final value = point.value;
    double? distanceMeters;
    double? totalCaloriesKcal;
    int? steps;
    int exerciseType = 0;
    if (value is WorkoutHealthValue) {
      distanceMeters = value.totalDistance?.toDouble();
      totalCaloriesKcal = value.totalEnergyBurned?.toDouble();
      steps = value.totalSteps;
      exerciseType = value.workoutActivityType.index;
    }
    return ExerciseData(
      id: point.uuid,
      title: point.workoutSummary?.workoutType,
      // TODO(health-pkg): HealthWorkoutActivityType maps to the plugin enum,
      //   not the Health Connect numeric ExerciseSessionRecord constant; the
      //   enum index is used as a stable placeholder.
      exerciseType: exerciseType,
      startTime: point.dateFrom.toUtc(),
      endTime: point.dateTo.toUtc(),
      durationMs: durationMs(point),
      source: sourceOf(point),
      totalDistanceMeters: distanceMeters,
      totalCaloriesKcal: totalCaloriesKcal,
      steps: steps,
      isOpenVitalsEntry: isOpenVitalsRecord(point, appPackageName),
    );
  }

  // ── Nutrition ─────────────────────────────────────────────────────────────

  static NutritionEntry nutritionEntry(
    HealthDataPoint point,
    String? appPackageName,
  ) {
    final value = point.value;
    final nutrientValues = <NutritionNutrient, double>{};
    double? energyKcal;
    double? proteinGrams;
    double? carbsGrams;
    double? fatGrams;
    double? fiberGrams;
    double? sugarGrams;
    String? name;
    int mealType = 0;
    if (value is NutritionHealthValue) {
      name = value.name;
      energyKcal = value.calories;
      proteinGrams = value.protein;
      carbsGrams = value.carbs;
      fatGrams = value.fat;
      fiberGrams = value.fiber;
      sugarGrams = value.sugar;
      void put(NutritionNutrient nutrient, double? grams) {
        if (grams != null && grams > 0) nutrientValues[nutrient] = grams;
      }

      if (energyKcal != null && energyKcal > 0) {
        nutrientValues[NutritionNutrient.energy] = energyKcal;
      }
      put(NutritionNutrient.protein, proteinGrams);
      put(NutritionNutrient.totalCarbohydrate, carbsGrams);
      put(NutritionNutrient.totalFat, fatGrams);
      put(NutritionNutrient.dietaryFiber, fiberGrams);
      put(NutritionNutrient.sugar, sugarGrams);
      // Caffeine is reported in grams by the health package.
      put(NutritionNutrient.caffeine, value.caffeine);
      put(NutritionNutrient.sodium, value.sodium);
      put(NutritionNutrient.potassium, value.potassium);
      put(NutritionNutrient.calcium, value.calcium);
      put(NutritionNutrient.iron, value.iron);
      put(NutritionNutrient.cholesterol, value.cholesterol);
      put(NutritionNutrient.saturatedFat, value.fatSaturated);
      put(NutritionNutrient.monounsaturatedFat, value.fatMonounsaturated);
      put(NutritionNutrient.polyunsaturatedFat, value.fatPolyunsaturated);
    }
    return NutritionEntry(
      time: point.dateFrom.toUtc(),
      endTime: point.dateTo.toUtc(),
      mealType: mealType,
      name: name,
      energyKcal: energyKcal,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      fiberGrams: fiberGrams,
      sugarGrams: sugarGrams,
      source: sourceOf(point),
      nutrientValues: nutrientValues,
      id: point.uuid,
      isOpenVitalsEntry: isOpenVitalsRecord(point, appPackageName),
    );
  }

  static HydrationEntry hydrationEntry(
    HealthDataPoint point,
    String? appPackageName,
  ) =>
      HydrationEntry(
        startTime: point.dateFrom.toUtc(),
        endTime: point.dateTo.toUtc(),
        // WATER is reported in litres.
        liters: numericValue(point).toDouble(),
        source: sourceOf(point),
        id: point.uuid,
        isOpenVitalsEntry: isOpenVitalsRecord(point, appPackageName),
      );

  // ── Daily-aggregation helpers (device-independent, pure) ──────────────────

  /// Groups instantaneous heart-rate samples into per-day min/avg/max summaries.
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

  /// Groups resting-HR samples into per-day averages.
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
          bpm: (byDate[date]!.fold<int>(0, (a, b) => a + b) / byDate[date]!.length)
              .round(),
        ),
    ];
  }

  /// Groups HRV samples into per-day RMSSD averages.
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
          rmssdMs:
              byDate[date]!.fold<double>(0, (a, b) => a + b) / byDate[date]!.length,
        ),
    ];
  }
}
