import 'package:flutter/material.dart';
import 'package:health/health.dart';

/// Human-readable workout labels + icons, ported from the Kotlin
/// `ExerciseLabels.kt`.
///
/// In the Kotlin app `exerciseType` is the Health Connect
/// `ExerciseSessionRecord.EXERCISE_TYPE_*` integer. The Dart port stores the
/// `health` package `HealthWorkoutActivityType` enum index instead (see
/// `HealthConnectMappers.exerciseData`), so labels/icons are resolved from that
/// enum rather than the numeric HC constants.
HealthWorkoutActivityType? _workoutTypeFor(int exerciseType) {
  if (exerciseType < 0 ||
      exerciseType >= HealthWorkoutActivityType.values.length) {
    return null;
  }
  return HealthWorkoutActivityType.values[exerciseType];
}

/// A title-cased label for the workout type (e.g. `RUNNING_TREADMILL` →
/// "Running Treadmill"), falling back to "Exercise".
String exerciseTypeLabel(int exerciseType) {
  final type = _workoutTypeFor(exerciseType);
  if (type == null) return 'Exercise';
  return _humanize(type.name);
}

String _humanize(String enumName) {
  final words = enumName.split('_').where((w) => w.isNotEmpty).map((word) {
    final lower = word.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  });
  final joined = words.join(' ');
  return joined.isEmpty ? 'Exercise' : joined;
}

/// A representative icon for the workout type, resolved from keywords in the
/// enum name (a pragmatic port of the Kotlin `exerciseTypeIcon` mapping).
IconData exerciseTypeIcon(int exerciseType) {
  final type = _workoutTypeFor(exerciseType);
  final name = (type?.name ?? '').toUpperCase();
  bool has(String token) => name.contains(token);

  if (has('RUN')) return Icons.directions_run;
  if (has('WALK') || has('HIK')) return Icons.directions_walk;
  if (has('BIK') || has('CYCL')) return Icons.directions_bike;
  if (has('SWIM') || has('WATER_POLO')) return Icons.pool;
  if (has('ROW') || has('PADDL') || has('KAYAK')) return Icons.rowing;
  if (has('YOGA') || has('PILATES') || has('STRETCH') || has('BREATH')) {
    return Icons.self_improvement;
  }
  if (has('WEIGHT') ||
      has('STRENGTH') ||
      has('CALISTHEN') ||
      has('CROSS') ||
      has('FUNCTIONAL')) {
    return Icons.fitness_center;
  }
  if (has('SKI') || has('SNOWBOARD') || has('SKAT')) {
    return Icons.downhill_skiing;
  }
  if (has('SURF')) return Icons.surfing;
  if (has('SAIL')) return Icons.sailing;
  if (has('GOLF')) return Icons.sports_golf;
  if (has('TENNIS') || has('BADMINTON') || has('SQUASH') || has('RACQUET')) {
    return Icons.sports_tennis;
  }
  if (has('BASKETBALL')) return Icons.sports_basketball;
  if (has('SOCCER')) return Icons.sports_soccer;
  if (has('FOOTBALL')) return Icons.sports_football;
  if (has('BASEBALL') || has('SOFTBALL')) return Icons.sports_baseball;
  if (has('CRICKET')) return Icons.sports_cricket;
  if (has('VOLLEYBALL')) return Icons.sports_volleyball;
  if (has('HANDBALL')) return Icons.sports_handball;
  if (has('HOCKEY')) return Icons.sports_hockey;
  if (has('MARTIAL') || has('BOXING')) return Icons.sports_martial_arts;
  if (has('GYMNASTICS')) return Icons.sports_gymnastics;
  if (has('WHEELCHAIR')) return Icons.accessible_forward;
  return Icons.fitness_center;
}
