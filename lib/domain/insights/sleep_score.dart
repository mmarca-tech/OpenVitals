import 'package:freezed_annotation/freezed_annotation.dart';

part 'sleep_score.freezed.dart';

/// Data-only stub of the insights `SleepScore` types referenced by
/// `DashboardData`. The scoring calculation lives outside the model layer and
/// is ported separately; only the estimate value type is needed here.
enum SleepScoreConfidence {
  high('HIGH'),
  medium('MEDIUM'),
  low('LOW'),
  noData('NO_DATA');

  const SleepScoreConfidence(this.storageName);

  /// Original Kotlin `.name` used for persistence round-trips.
  final String storageName;

  static SleepScoreConfidence? fromStorage(String value) {
    for (final entry in values) {
      if (entry.storageName == value) return entry;
    }
    return null;
  }
}

@freezed
abstract class SleepScoreEstimate with _$SleepScoreEstimate {
  const factory SleepScoreEstimate({
    @Default(0) int score,
    @Default(SleepScoreConfidence.noData) SleepScoreConfidence confidence,
    @Default(0.0) double durationPoints,
    @Default(0.0) double efficiencyPoints,
    @Default(0.0) double continuityPoints,
    @Default(0.0) double regularityPoints,
    @Default(0.0) double sleepDurationMinutes,
    @Default(0.0) double timeInBedMinutes,
    @Default(0.0) double sleepEfficiencyPercent,
    @Default(0.0) double wakeAfterSleepOnsetMinutes,
    double? regularityDifferenceMinutes,
    @Default(0) int regularityBaselineNights,
    @Default(0) int sleepStageCount,
    @Default(false) bool usesSleepStages,
    @Default(false) bool usesExplicitAwakeStages,
  }) = _SleepScoreEstimate;

  static const SleepScoreEstimate noData = SleepScoreEstimate();
}
