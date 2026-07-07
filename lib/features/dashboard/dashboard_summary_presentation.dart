import 'package:flutter/material.dart';

import '../../core/presentation/unit_formatter.dart';
import '../../domain/insights/sleep_score.dart';
import '../../domain/model/dashboard_data.dart';
import '../../navigation/app_routes.dart';
import '../../ui/theme/app_colors.dart';

/// Presentation data for one of the two hero ring cards (Steps, Weekly cardio).
/// Port of the Kotlin `DashboardSummaryCard` inputs.
class RingCardData {
  const RingCardData({
    required this.title,
    required this.value,
    required this.accent,
    required this.progress,
    required this.location,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final Color accent;
  final double progress;
  final String location;
}

/// Presentation data for one small metric stat tile in the carousel. Port of the
/// Kotlin `MetricStatCard` / `DashboardPresentationMapper` widget models.
class StatTileData {
  const StatTileData({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.location,
    this.unit,
    this.subtitle,
    this.message,
    this.showTitle = true,
    this.progress,
  });

  final String title;
  final String value;
  final String? unit;
  final IconData icon;
  final Color accent;
  final String? subtitle;
  final String? message;
  final bool showTitle;
  final double? progress;
  final String location;
}

/// The fully-mapped dashboard summary: the two fixed ring cards plus the ordered
/// list of carousel stat tiles.
class DashboardSummary {
  const DashboardSummary({
    required this.steps,
    required this.weeklyCardio,
    required this.tiles,
  });

  final RingCardData steps;
  final RingCardData weeklyCardio;
  final List<StatTileData> tiles;
}

/// Default daily goals, from the Kotlin `DashboardDailyGoals` /
/// `MetricDailyGoalKey` defaults. The Flutter port has no per-user goal store
/// yet, so these fixed defaults drive the ring/tile progress fractions.
class _Goals {
  const _Goals._();
  static const double steps = 8000;
  static const double distanceMeters = 5000;
  static const double caloriesOutKcal = 2000;
  static const double activeCaloriesKcal = 400;
  static const double floors = 10;
  static const double elevationMeters = 100;
  static const double wheelchairPushes = 1000;
  static const double sleepHours = 8;
  static const double hydrationLiters = 2;
  static const double caloriesInKcal = 2000;
  static const double proteinGrams = 50;
  static const double carbsGrams = 275;
  static const double fatGrams = 70;
  static const double mindfulnessMinutes = 10;
}

double _fraction(double current, double target) =>
    target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

/// Maps a fully-loaded [DashboardData] onto the summary UI model, mirroring the
/// Kotlin `DashboardPresentationMapper` (metric selection, icons, accent, value
/// formatting and goal-progress). Optional metrics only produce a tile when they
/// carry data; a small "always shown" required set (distance, hydration, body
/// fat, heart rate, resting HR, mindfulness) renders regardless, matching the
/// Kotlin default dashboard layout.
DashboardSummary buildDashboardSummary(DashboardData data, UnitFormatter f) {
  final steps = RingCardData(
    title: 'Steps',
    value: f.count(data.steps),
    subtitle: 'steps of ${f.count(_Goals.steps.round())}',
    accent: AppColors.steps,
    progress: _fraction(data.steps.toDouble(), _Goals.steps),
    location: AppRoutes.metricLocation('STEPS'),
  );

  final wcl = data.weeklyCardioLoad;
  final weeklyCardio = wcl != null
      ? RingCardData(
          title: 'Weekly cardio',
          value: '${wcl.progressPercent}%',
          subtitle: '${wcl.currentScore} of ${wcl.targetScore}',
          accent: AppColors.workout,
          progress: wcl.progressFraction,
          location: AppRoutes.cardioLoadDetail,
        )
      : const RingCardData(
          title: 'Weekly cardio',
          value: '—',
          subtitle: 'No data',
          accent: AppColors.workout,
          progress: 0,
          location: AppRoutes.cardioLoadDetail,
        );

  final tiles = <StatTileData>[];
  void add(StatTileData? tile) {
    if (tile != null) tiles.add(tile);
  }

  // ── Activity ──────────────────────────────────────────────────────────────
  final distance = f.distance(data.distanceMeters);
  add(StatTileData(
    title: 'Distance',
    value: distance.value,
    unit: distance.unit,
    icon: Icons.straighten,
    accent: AppColors.distance,
    progress: _fraction(data.distanceMeters, _Goals.distanceMeters),
    location: AppRoutes.metricLocation('DISTANCE'),
  ));

  if (data.caloriesKcal > 0) {
    final energy = f.energy(data.caloriesKcal);
    add(StatTileData(
      title: 'Total calories',
      value: energy.value,
      unit: energy.unit,
      icon: Icons.local_fire_department,
      accent: AppColors.calories,
      progress: _fraction(data.caloriesKcal, _Goals.caloriesOutKcal),
      location: AppRoutes.calories,
    ));
  }

  final activeCalories = data.activeCaloriesKcal;
  if (activeCalories != null && activeCalories > 0) {
    final energy = f.energy(activeCalories);
    add(StatTileData(
      title: 'Active calories',
      value: energy.value,
      unit: energy.unit,
      icon: Icons.local_fire_department,
      accent: AppColors.activeCalories,
      progress: _fraction(activeCalories, _Goals.activeCaloriesKcal),
      location: AppRoutes.calories,
    ));
  }

  final floors = data.floorsClimbed;
  if (floors != null && floors > 0) {
    add(StatTileData(
      title: 'Floors',
      value: f.count(floors),
      icon: Icons.stairs,
      accent: AppColors.floors,
      progress: _fraction(floors.toDouble(), _Goals.floors),
      location: AppRoutes.metricLocation('FLOORS'),
    ));
  }

  final elevation = data.elevationGainedMeters;
  if (elevation != null && elevation > 0) {
    final ev = f.elevation(elevation);
    add(StatTileData(
      title: 'Elevation',
      value: ev.value,
      unit: ev.unit,
      icon: Icons.terrain,
      accent: AppColors.elevation,
      progress: _fraction(elevation, _Goals.elevationMeters),
      location: AppRoutes.metricLocation('ELEVATION'),
    ));
  }

  final pushes = data.wheelchairPushes;
  if (pushes != null && pushes > 0) {
    add(StatTileData(
      title: 'Wheelchair pushes',
      value: f.count(pushes),
      icon: Icons.accessible_forward,
      accent: AppColors.wheelchairPushes,
      progress: _fraction(pushes.toDouble(), _Goals.wheelchairPushes),
      location: AppRoutes.metricLocation('WHEELCHAIR_PUSHES'),
    ));
  }

  // ── Sleep ─────────────────────────────────────────────────────────────────
  final sleep = data.sleep;
  if (sleep != null) {
    final score = data.sleepScore;
    final subtitle = score.confidence != SleepScoreConfidence.noData
        ? '${score.score} · ${_sleepRating(score.score)}'
        : null;
    add(StatTileData(
      title: 'Sleep',
      value: f.duration(sleep.durationMs),
      icon: Icons.bed,
      accent: AppColors.sleep,
      subtitle: subtitle,
      showTitle: false,
      progress: _fraction(
        sleep.durationMs.toDouble(),
        _Goals.sleepHours * 3600 * 1000,
      ),
      location: AppRoutes.sleep,
    ));
  }

  // ── Hydration ─────────────────────────────────────────────────────────────
  final hydration = f.hydration(data.hydrationLiters);
  add(StatTileData(
    title: 'Beverages',
    value: hydration.value,
    unit: hydration.unit,
    icon: Icons.local_drink,
    accent: AppColors.hydration,
    progress: _fraction(data.hydrationLiters, _Goals.hydrationLiters),
    location: AppRoutes.hydrationEntry,
  ));

  // ── Nutrition ─────────────────────────────────────────────────────────────
  final caloriesIn = data.caloriesInKcal;
  if (caloriesIn != null && caloriesIn > 0) {
    final energy = f.energy(caloriesIn);
    add(StatTileData(
      title: 'Calories in',
      value: energy.value,
      unit: energy.unit,
      icon: Icons.restaurant,
      accent: AppColors.nutrition,
      progress: _fraction(caloriesIn, _Goals.caloriesInKcal),
      location: AppRoutes.nutrition,
    ));
  }

  add(_gramTile(
    title: 'Protein',
    grams: data.proteinGrams,
    goal: _Goals.proteinGrams,
    f: f,
  ));
  add(_gramTile(
    title: 'Carbs',
    grams: data.carbsGrams,
    goal: _Goals.carbsGrams,
    f: f,
  ));
  add(_gramTile(
    title: 'Fat',
    grams: data.fatGrams,
    goal: _Goals.fatGrams,
    f: f,
  ));

  final caffeine = data.caffeineGrams;
  if (caffeine != null && caffeine > 0) {
    add(StatTileData(
      title: 'Caffeine',
      value: f.decimal(caffeine * 1000, 0),
      unit: 'mg',
      icon: Icons.restaurant,
      accent: AppColors.nutrition,
      location: AppRoutes.nutrition,
    ));
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  final weight = data.weightKg;
  if (weight != null && weight > 0) {
    final wv = f.weight(weight);
    add(StatTileData(
      title: 'Weight',
      value: wv.value,
      unit: wv.unit,
      icon: Icons.monitor_weight,
      accent: AppColors.weight,
      location: AppRoutes.body,
    ));
  }

  final height = data.heightCm;
  if (height != null && height > 0) {
    final hv = f.height(height);
    add(StatTileData(
      title: 'Height',
      value: hv.value,
      unit: hv.unit,
      icon: Icons.monitor_weight,
      accent: AppColors.weight,
      location: AppRoutes.body,
    ));
  }

  final bmi = data.bmi;
  if (bmi != null && bmi > 0) {
    add(StatTileData(
      title: 'BMI',
      value: f.decimal(bmi, 1),
      icon: Icons.monitor_weight,
      accent: AppColors.weight,
      location: AppRoutes.body,
    ));
  }

  final ffmi = data.ffmi;
  if (ffmi != null && ffmi > 0) {
    add(StatTileData(
      title: 'FFMI',
      value: f.decimal(ffmi, 1),
      icon: Icons.fitness_center,
      accent: AppColors.bodyFat,
      location: AppRoutes.body,
    ));
  }

  // Body fat is a "required" tile (always shown).
  final bodyFat = f.percent(data.bodyFatPercent);
  add(StatTileData(
    title: 'Body fat',
    value: bodyFat.value,
    unit: bodyFat.unit,
    icon: Icons.monitor_weight,
    accent: AppColors.bodyFat,
    location: AppRoutes.body,
  ));

  final leanMass = data.leanMassKg;
  if (leanMass != null && leanMass > 0) {
    final lv = f.bodyMass(leanMass);
    add(StatTileData(
      title: 'Lean mass',
      value: lv.value,
      unit: lv.unit,
      icon: Icons.monitor_weight,
      accent: AppColors.weight,
      location: AppRoutes.body,
    ));
  }

  // ── Heart & vitals ────────────────────────────────────────────────────────
  // Heart rate + resting HR are "required" tiles (always shown).
  final avgHr = f.heartRate(data.avgHeartRateBpm);
  add(StatTileData(
    title: 'Heart rate',
    value: avgHr.value,
    unit: avgHr.unit,
    icon: Icons.favorite,
    accent: AppColors.vitals,
    location: AppRoutes.metricLocation('AVG_HEART_RATE'),
  ));

  final restingHr = f.heartRate(data.restingHeartRateBpm);
  add(StatTileData(
    title: 'Resting HR',
    value: restingHr.value,
    unit: restingHr.unit,
    icon: Icons.favorite,
    accent: AppColors.vitals,
    location: AppRoutes.metricLocation('RESTING_HEART_RATE'),
  ));

  final hrv = data.hrvRmssdMs;
  if (hrv != null && hrv > 0) {
    final hv = f.hrv(hrv);
    add(StatTileData(
      title: 'HRV',
      value: hv.value,
      unit: hv.unit,
      icon: Icons.favorite_border,
      accent: AppColors.vitals,
      location: AppRoutes.metricLocation('HRV'),
    ));
  }

  final systolic = data.latestSystolicMmHg;
  final diastolic = data.latestDiastolicMmHg;
  if (systolic != null && diastolic != null) {
    final bp = f.bloodPressure(systolic, diastolic);
    add(StatTileData(
      title: 'Blood pressure',
      value: bp.value,
      unit: bp.unit,
      icon: Icons.favorite,
      accent: AppColors.vitals,
      location: AppRoutes.metricLocation('BLOOD_PRESSURE'),
    ));
  }

  final spo2 = data.latestSpO2Percent;
  if (spo2 != null) {
    final sv = f.percent(spo2);
    add(StatTileData(
      title: 'Blood oxygen',
      value: sv.value,
      unit: sv.unit,
      icon: Icons.favorite_border,
      accent: AppColors.vitals,
      location: AppRoutes.metricLocation('SPO2'),
    ));
  }

  final vo2 = data.latestVo2Max;
  if (vo2 != null) {
    final vv = f.vo2Max(vo2);
    add(StatTileData(
      title: 'VO₂ max',
      value: vv.value,
      unit: vv.unit,
      icon: Icons.directions_run,
      accent: AppColors.vitals,
      location: AppRoutes.metricLocation('VO2_MAX'),
    ));
  }

  final respiratory = data.avgRespiratoryRate;
  if (respiratory != null && respiratory > 0) {
    final rv = f.respiratoryRate(respiratory);
    add(StatTileData(
      title: 'Respiratory rate',
      value: rv.value,
      unit: rv.unit,
      icon: Icons.favorite,
      accent: AppColors.vitals,
      location: AppRoutes.metricLocation('RESPIRATORY_RATE'),
    ));
  }

  final bodyTemp = data.latestBodyTemperatureCelsius;
  if (bodyTemp != null) {
    final tv = f.temperature(bodyTemp);
    add(StatTileData(
      title: 'Body temperature',
      value: tv.value,
      unit: tv.unit,
      icon: Icons.device_thermostat,
      accent: AppColors.vitals,
      location: AppRoutes.metricLocation('BODY_TEMPERATURE'),
    ));
  }

  // ── Mindfulness (required tile) ───────────────────────────────────────────
  final mindfulness = f.minutes(data.mindfulnessMinutes ?? 0);
  add(StatTileData(
    title: 'Mindfulness',
    value: mindfulness.value,
    unit: mindfulness.unit,
    icon: Icons.self_improvement,
    accent: AppColors.mindfulness,
    progress: _fraction(
      (data.mindfulnessMinutes ?? 0).toDouble(),
      _Goals.mindfulnessMinutes,
    ),
    location: AppRoutes.mindfulnessEntry,
  ));

  return DashboardSummary(
    steps: steps,
    weeklyCardio: weeklyCardio,
    tiles: tiles,
  );
}

StatTileData? _gramTile({
  required String title,
  required double? grams,
  required double goal,
  required UnitFormatter f,
}) {
  if (grams == null || grams <= 0) return null;
  return StatTileData(
    title: title,
    value: f.count(grams.round()),
    unit: 'g',
    icon: Icons.restaurant,
    accent: AppColors.nutrition,
    progress: _fraction(grams, goal),
    location: AppRoutes.nutrition,
  );
}

/// Sleep-score rating label, from the Kotlin `sleepScoreRatingLabel(score)`.
String _sleepRating(int score) {
  if (score >= 90) return 'Excellent';
  if (score >= 80) return 'Good';
  if (score >= 60) return 'Fair';
  return 'Poor';
}
