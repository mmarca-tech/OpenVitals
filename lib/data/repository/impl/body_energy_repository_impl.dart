import 'dart:math' as math;

import '../../../core/time/local_date.dart';
import '../../../data/prefs/preferences_repository.dart';
import '../../../data/repository/body_energy_timeline_cache_store.dart';
import '../../../domain/dashboard/dashboard_aggregator.dart';
import '../../../domain/insights/body_energy_timeline.dart';
import '../../../domain/model/refresh_mode.dart';
import '../../../domain/preferences/body_energy_calibration.dart';
import '../../../domain/preferences/body_profile.dart';
import '../contract/body_energy_repository.dart';
import '../contract/activity_repository.dart';
import '../contract/heart_repository.dart';
import '../contract/health_repository.dart';
import '../contract/sleep_repository.dart';
import '../contract/vitals_repository.dart';
import 'repository_time.dart';

/// Port of the Kotlin `BodyEnergyRepositoryImpl`.
///
/// Composes the heart / sleep / activity / vitals repositories to build a
/// per-day body-energy timeline via [calculateBodyEnergyTimeline], with a
/// per-day cache keyed by a permission/calibration signature.
class BodyEnergyRepositoryImpl implements BodyEnergyRepository {
  BodyEnergyRepositoryImpl({
    required HeartRepository heartRepository,
    required SleepRepository sleepRepository,
    required ActivityRepository activityRepository,
    required VitalsRepository vitalsRepository,
    required HealthRepository healthRepository,
    required PreferencesRepository preferencesRepository,
    required BodyEnergyTimelineCacheStore cacheStore,
  })  : _heart = heartRepository,
        _sleep = sleepRepository,
        _activity = activityRepository,
        _vitals = vitalsRepository,
        _health = healthRepository,
        _preferences = preferencesRepository,
        _cache = cacheStore;

  final HeartRepository _heart;
  final SleepRepository _sleep;
  final ActivityRepository _activity;
  final VitalsRepository _vitals;
  final HealthRepository _health;
  final PreferencesRepository _preferences;
  final BodyEnergyTimelineCacheStore _cache;

  static const int _baselineDays = 28;

  @override
  Future<BodyEnergyTimelineResult> loadTimeline(
    BodyEnergyTimelineQuery query,
  ) async {
    final calibration = _preferences.bodyEnergyCalibrationListenable.value;
    final bodyProfile = _preferences.bodyProfileListenable.value;
    final granted = await _health.grantedPermissions();
    final signature = 'v1|${_health.availability().name}|${granted.length}'
        '|${calibration.hashCode}|${bodyProfile.hashCode}';

    final days = <BodyEnergyTimeline>[];
    int? previousEndScore;
    var date = query.period.start;
    while (!date.isAfter(query.period.end)) {
      final timeline = await _loadDay(
        date: date,
        refreshMode: query.refreshMode,
        signature: signature,
        previousEndScore: previousEndScore,
        calibration: calibration,
        bodyProfile: bodyProfile,
      );
      days.add(timeline);
      previousEndScore = timeline.currentScore;
      date = date.plusDays(1);
    }
    return BodyEnergyTimelineResult(query: query, days: days);
  }

  Future<BodyEnergyTimeline> _loadDay({
    required LocalDate date,
    required RefreshMode refreshMode,
    required String signature,
    required int? previousEndScore,
    required BodyEnergyCalibration calibration,
    required BodyProfile bodyProfile,
  }) async {
    if (refreshMode == RefreshMode.normal) {
      final cached = _cache.load(date, signature);
      if (cached != null) return cached;
    }

    final dayStart = localDayStart(date);
    final dayEnd = localDayEnd(date);

    final heartRateSamples =
        await _heart.loadRawHeartRateSamplesForDayGraph(date);
    final hrvSamples = await _heart.loadHrvSamples(dayStart, dayEnd);
    final sleepSessions =
        await _sleep.loadSleepSessions(date.minusDays(1), date);
    final workouts = await _activity.loadWorkouts(date, date);
    final respiratory = await _vitals.loadRespiratoryRate(date, date);
    final restingHr = await _heart.loadRestingHeartRate(date);

    final baselineResting = DashboardAggregator.medianLongOrNull(
      (await _heart.loadDailyRestingHR(date.minusDays(_baselineDays), date.minusDays(1)))
          .map((e) => e.bpm)
          .where((v) => v > 0)
          .toList(),
    );
    final baselineHrv = DashboardAggregator.medianDoubleValuesOrNull(
      (await _heart.loadDailyHRV(date.minusDays(_baselineDays), date.minusDays(1)))
          .map((e) => e.rmssdMs)
          .where((v) => v > 0)
          .toList(),
    );
    final observedMax = heartRateSamples.isEmpty
        ? null
        : heartRateSamples
            .map((s) => s.beatsPerMinute)
            .reduce((a, b) => math.max(a, b));

    final timeline = calculateBodyEnergyTimeline(
      BodyEnergyTimelineInputs(
        date: date,
        heartRateSamples: heartRateSamples,
        hrvSamples: hrvSamples,
        sleepSessions: sleepSessions,
        workouts: workouts,
        respiratoryRateSamples: respiratory,
        restingHeartRateBpm: restingHr,
        baselineRestingHeartRateBpm: baselineResting,
        observedMaxHeartRateBpm: observedMax,
        hrvBaselineRmssdMs: baselineHrv,
        previousEndScore: previousEndScore,
        calibration: calibration,
        bodyProfile: bodyProfile,
      ),
    ).copyWith(signature: signature);

    if (refreshMode == RefreshMode.normal) {
      await _cache.save(timeline);
    }
    return timeline;
  }
}
