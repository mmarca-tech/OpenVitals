import 'package:health/health.dart';

/// Port of the Kotlin `ActivityEntryTypes.kt` (activity type catalogue) plus the
/// Health Connect `ExerciseSessionRecord` / `ExerciseSegment` /
/// `PlannedExerciseStep` constants the manual-entry + recording feature depends
/// on.
///
/// Fidelity note: the Kotlin app keyed activity types on the Health Connect
/// `ExerciseSessionRecord.EXERCISE_TYPE_*` integers. The Dart app stores the
/// `health` package `HealthWorkoutActivityType` enum index for `exerciseType`
/// (see `HealthConnectMappers.exerciseData` and `exercise_labels.dart`), so the
/// [ExerciseSessionType] ids below are the matching enum indices. That keeps the
/// value consistent everywhere it flows (labels, icons, edit-mode inference).
/// Exercise-segment types and planned-step phases have no `health` enum, so they
/// use the verbatim Health Connect integer constants.
class ExerciseSessionType {
  const ExerciseSessionType._();

  static final int running = HealthWorkoutActivityType.RUNNING.index;
  static final int biking = HealthWorkoutActivityType.BIKING.index;
  static final int walking = HealthWorkoutActivityType.WALKING.index;
  static final int hiking = HealthWorkoutActivityType.HIKING.index;
  static final int wheelchair = HealthWorkoutActivityType.WHEELCHAIR.index;
  static final int rowing = HealthWorkoutActivityType.ROWING.index;
  static final int paddling = HealthWorkoutActivityType.PADDLE_SPORTS.index;
  static final int skiing = HealthWorkoutActivityType.SKIING.index;
  static final int snowboarding = HealthWorkoutActivityType.SNOWBOARDING.index;
  static final int snowshoeing = HealthWorkoutActivityType.SNOWSHOEING.index;
  static final int skating = HealthWorkoutActivityType.SKATING.index;
  static final int sailing = HealthWorkoutActivityType.SAILING.index;
  static final int surfing = HealthWorkoutActivityType.SURFING.index;
  static final int swimmingOpenWater =
      HealthWorkoutActivityType.SWIMMING_OPEN_WATER.index;
  static final int golf = HealthWorkoutActivityType.GOLF.index;
  static final int strengthTraining =
      HealthWorkoutActivityType.STRENGTH_TRAINING.index;
  static final int runningTreadmill =
      HealthWorkoutActivityType.RUNNING_TREADMILL.index;
  static final int calisthenics = HealthWorkoutActivityType.CALISTHENICS.index;
  static final int gymnastics = HealthWorkoutActivityType.GYMNASTICS.index;
  static final int otherWorkout = HealthWorkoutActivityType.OTHER.index;
}

/// Verbatim Health Connect `ExerciseSegment.EXERCISE_SEGMENT_TYPE_*` constants.
class ExerciseSegmentType {
  const ExerciseSegmentType._();

  static const int unknown = 0;
  static const int jumpRope = 28;
  static const int otherWorkout = 38;
  static const int pause = 39;
  static const int pullUp = 42;
  static const int rest = 44;
  static const int runningTreadmill = 47;
}

/// Verbatim Health Connect `PlannedExerciseStep.EXERCISE_PHASE_*` constants.
class PlannedExerciseStepPhase {
  const PlannedExerciseStepPhase._();

  static const int unknown = 0;
  static const int warmup = 1;
  static const int rest = 2;
  static const int active = 3;
}

/// Which live-recording sensor an activity type records from.
enum ActivityRecordingSensor {
  none,
  gps,
  ble,
  proximity,
  accelerometer,
  stepDetector,
}

/// The unit a repetition-like activity counts in.
enum ActivityRepetitionUnit {
  repetitions,
  steps,
}

/// Port of the Kotlin `ActivityEntryType` data class.
class ActivityEntryType {
  ActivityEntryType({
    required this.exerciseType,
    required this.label,
    String? id,
    this.supportsGpsRoute = true,
    this.supportsDistance = true,
    this.supportsElevation = false,
    ActivityRecordingSensor? recordingSensor,
    this.segmentType,
    this.defaultTitle,
    this.repetitionUnit,
  })  : id = id ?? exerciseType.toString(),
        recordingSensor = recordingSensor ??
            (supportsGpsRoute
                ? ActivityRecordingSensor.gps
                : ActivityRecordingSensor.none);

  final int exerciseType;
  final String id;
  final String label;
  final bool supportsGpsRoute;
  final bool supportsDistance;
  final bool supportsElevation;
  final ActivityRecordingSensor recordingSensor;
  final int? segmentType;
  final String? defaultTitle;
  final ActivityRepetitionUnit? repetitionUnit;

  bool get supportsLiveRecording =>
      recordingSensor != ActivityRecordingSensor.none;

  bool get supportsSetRepetitions =>
      repetitionUnit == ActivityRepetitionUnit.repetitions;

  bool get isRepetitionLike => repetitionUnit != null;

  bool get supportsStepCounting =>
      repetitionUnit == ActivityRepetitionUnit.steps;

  @override
  bool operator ==(Object other) =>
      other is ActivityEntryType && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Port of the Kotlin `activityEntryTypeById`.
ActivityEntryType? activityEntryTypeById(String? id) {
  if (id == null) return null;
  for (final type in defaultActivityEntryTypes) {
    if (type.id == id) return type;
  }
  return null;
}

/// Port of the Kotlin `DefaultActivityEntryTypes`.
final List<ActivityEntryType> defaultActivityEntryTypes = <ActivityEntryType>[
  ActivityEntryType(
    exerciseType: ExerciseSessionType.running,
    label: 'Running',
    supportsElevation: true,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.biking,
    label: 'Cycling',
    supportsElevation: true,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.walking,
    label: 'Walking',
    supportsElevation: true,
    repetitionUnit: ActivityRepetitionUnit.steps,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.hiking,
    label: 'Hiking',
    supportsElevation: true,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.wheelchair,
    label: 'Wheelchair',
    supportsElevation: true,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.rowing,
    label: 'Rowing',
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.paddling,
    label: 'Paddling',
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.skiing,
    label: 'Skiing',
    supportsElevation: true,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.snowboarding,
    label: 'Snowboarding',
    supportsElevation: true,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.snowshoeing,
    label: 'Snowshoeing',
    supportsElevation: true,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.skating,
    label: 'Skating',
    supportsElevation: true,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.sailing,
    label: 'Sailing',
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.surfing,
    label: 'Surfing',
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.swimmingOpenWater,
    label: 'Open water swimming',
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.golf,
    label: 'Golf',
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.strengthTraining,
    label: 'Strength training',
    supportsGpsRoute: false,
    supportsDistance: false,
    recordingSensor: ActivityRecordingSensor.ble,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.runningTreadmill,
    id: 'treadmill',
    label: 'Treadmill',
    supportsGpsRoute: false,
    supportsDistance: true,
    recordingSensor: ActivityRecordingSensor.stepDetector,
    segmentType: ExerciseSegmentType.runningTreadmill,
    repetitionUnit: ActivityRepetitionUnit.steps,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.calisthenics,
    id: 'push_ups',
    label: 'Push-ups',
    supportsGpsRoute: false,
    supportsDistance: false,
    recordingSensor: ActivityRecordingSensor.proximity,
    segmentType: ExerciseSegmentType.otherWorkout,
    defaultTitle: 'Push-ups',
    repetitionUnit: ActivityRepetitionUnit.repetitions,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.calisthenics,
    id: 'pull_ups',
    label: 'Pull-ups',
    supportsGpsRoute: false,
    supportsDistance: false,
    recordingSensor: ActivityRecordingSensor.accelerometer,
    segmentType: ExerciseSegmentType.pullUp,
    repetitionUnit: ActivityRepetitionUnit.repetitions,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.calisthenics,
    id: 'rope_skipping',
    label: 'Rope skipping',
    supportsGpsRoute: false,
    supportsDistance: false,
    recordingSensor: ActivityRecordingSensor.accelerometer,
    segmentType: ExerciseSegmentType.jumpRope,
    repetitionUnit: ActivityRepetitionUnit.repetitions,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.gymnastics,
    id: 'trampoline_jumping',
    label: 'Trampoline jumping',
    supportsGpsRoute: false,
    supportsDistance: false,
    recordingSensor: ActivityRecordingSensor.accelerometer,
    segmentType: ExerciseSegmentType.otherWorkout,
    defaultTitle: 'Trampoline jumping',
    repetitionUnit: ActivityRepetitionUnit.repetitions,
  ),
  ActivityEntryType(
    exerciseType: ExerciseSessionType.otherWorkout,
    label: 'Other workout',
    supportsGpsRoute: false,
    supportsDistance: false,
  ),
];
