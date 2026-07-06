import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/time/local_date.dart';

part 'body_energy_timeline.freezed.dart';

/// Data-only stub of the insights `BodyEnergyTimeline` model referenced by
/// `DashboardData`. The timeline calculation lives outside the model layer and
/// is ported separately; only the value types are needed here.
const int bodyEnergyTimelineBucketMinutes = 5;
const int bodyEnergyTimelineAlgorithmVersion = 2;

enum BodyEnergyConfidence {
  high('HIGH'),
  medium('MEDIUM'),
  low('LOW'),
  noData('NO_DATA');

  const BodyEnergyConfidence(this.storageName);

  final String storageName;

  static BodyEnergyConfidence? fromStorage(String value) {
    for (final entry in values) {
      if (entry.storageName == value) return entry;
    }
    return null;
  }
}

enum BodyEnergyBucketState {
  sleep('SLEEP'),
  rest('REST'),
  activity('ACTIVITY'),
  stress('STRESS'),
  unmeasurable('UNMEASURABLE');

  const BodyEnergyBucketState(this.storageName);

  final String storageName;

  static BodyEnergyBucketState? fromStorage(String value) {
    for (final entry in values) {
      if (entry.storageName == value) return entry;
    }
    return null;
  }
}

enum BodyEnergyPrimaryInfluence {
  sleepRecovery('SLEEP_RECOVERY'),
  quietRest('QUIET_REST'),
  exertion('EXERTION'),
  elevatedHeartRate('ELEVATED_HEART_RATE'),
  recoveryDebt('RECOVERY_DEBT'),
  noData('NO_DATA'),
  steady('STEADY');

  const BodyEnergyPrimaryInfluence(this.storageName);

  final String storageName;

  static BodyEnergyPrimaryInfluence? fromStorage(String value) {
    for (final entry in values) {
      if (entry.storageName == value) return entry;
    }
    return null;
  }
}

enum BodyEnergyCalibrationMode {
  automatic('AUTOMATIC'),
  manualValues('MANUAL_VALUES'),
  manualZones('MANUAL_ZONES');

  const BodyEnergyCalibrationMode(this.storageName);

  final String storageName;

  static BodyEnergyCalibrationMode? fromStorage(String value) {
    for (final entry in values) {
      if (entry.storageName == value) return entry;
    }
    return null;
  }
}

@freezed
abstract class BodyEnergyTimelinePoint with _$BodyEnergyTimelinePoint {
  const factory BodyEnergyTimelinePoint.build({
    required DateTime time,
    required int score,
    required double delta,
    required BodyEnergyBucketState state,
    required BodyEnergyConfidence confidence,
    required double charge,
    required double intensityDrain,
    required double stressDrain,
    required double recoveryDebtDrain,
    required BodyEnergyPrimaryInfluence primaryInfluence,
  }) = _BodyEnergyTimelinePoint;

  factory BodyEnergyTimelinePoint({
    required DateTime time,
    required int score,
    required double delta,
    required BodyEnergyBucketState state,
    required BodyEnergyConfidence confidence,
    double? charge,
    double intensityDrain = 0.0,
    double stressDrain = 0.0,
    double recoveryDebtDrain = 0.0,
    BodyEnergyPrimaryInfluence primaryInfluence =
        BodyEnergyPrimaryInfluence.steady,
  }) =>
      BodyEnergyTimelinePoint.build(
        time: time,
        score: score,
        delta: delta,
        state: state,
        confidence: confidence,
        charge: charge ?? math.max(delta, 0.0),
        intensityDrain: intensityDrain,
        stressDrain: stressDrain,
        recoveryDebtDrain: recoveryDebtDrain,
        primaryInfluence: primaryInfluence,
      );
}

@freezed
abstract class BodyEnergyInputSummary with _$BodyEnergyInputSummary {
  const factory BodyEnergyInputSummary({
    @Default(bodyEnergyTimelineAlgorithmVersion) int algorithmVersion,
    @Default(bodyEnergyTimelineBucketMinutes) int bucketMinutes,
    @Default(0) int heartRateSampleCount,
    @Default(0) int hrvSampleCount,
    @Default(0) int sleepSessionCount,
    @Default(0) int workoutCount,
    @Default(0) int respiratorySampleCount,
    @Default(false) bool hasRestingHeartRate,
    @Default(false) bool hasBaselineRestingHeartRate,
    @Default(false) bool hasObservedMaxHeartRate,
    @Default(false) bool hasHrvBaseline,
    @Default(false) bool hasRespiratoryBaseline,
    int? previousEndScore,
    @Default(BodyEnergyCalibrationMode.automatic)
    BodyEnergyCalibrationMode calibrationMode,
  }) = _BodyEnergyInputSummary;
}

@freezed
abstract class BodyEnergyTimeline with _$BodyEnergyTimeline {
  const factory BodyEnergyTimeline({
    required LocalDate date,
    required int startScore,
    required int currentScore,
    required int charged,
    required int drained,
    required List<BodyEnergyTimelinePoint> points,
    required BodyEnergyConfidence confidence,
    required String confidenceReason,
    @Default(BodyEnergyInputSummary()) BodyEnergyInputSummary inputSummary,
    DateTime? generatedAt,
    @Default('') String signature,
  }) = _BodyEnergyTimeline;

  static BodyEnergyTimeline empty({
    required LocalDate date,
    required String reason,
    BodyEnergyInputSummary inputSummary = const BodyEnergyInputSummary(),
  }) =>
      BodyEnergyTimeline(
        date: date,
        startScore: 50,
        currentScore: 50,
        charged: 0,
        drained: 0,
        points: const [],
        confidence: BodyEnergyConfidence.noData,
        confidenceReason: reason,
        inputSummary: inputSummary,
      );
}
