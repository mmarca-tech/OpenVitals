import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/period/period_calculations.dart';
import '../../core/period/period_selection.dart';
import '../../core/period/time_range.dart';
import '../../core/presentation/screen_error.dart';
import '../../core/time/local_date.dart';
import '../../di/providers.dart';
import '../../domain/model/activity_models.dart';

part 'activities_notifier.freezed.dart';

/// The Riverpod port of the Kotlin `ActivitiesUiState`, trimmed to the workout
/// list + planned workouts the port surfaces (the Kotlin cross-metric overview
/// days / cardio-load rollup are out of scope for this batch).
@freezed
abstract class ActivitiesState with _$ActivitiesState {
  const ActivitiesState._();

  const factory ActivitiesState({
    required LocalDate selectedDate,
    @Default(TimeRange.week) TimeRange selectedRange,
    @Default(true) bool isLoading,
    ScreenError? error,
    @Default(<ExerciseData>[]) List<ExerciseData> workouts,
    @Default(<PlannedExerciseData>[]) List<PlannedExerciseData> plannedWorkouts,
  }) = _ActivitiesState;

  /// Total recorded duration across the period's workouts.
  int get totalDurationMs =>
      workouts.fold<int>(0, (sum, w) => sum + w.durationMs);

  /// Total recorded distance (metres) across the period's workouts.
  double get totalDistanceMeters => workouts.fold<double>(
        0.0,
        (sum, w) => sum + (w.totalDistanceMeters ?? 0.0),
      );
}

/// The Riverpod port of the Kotlin `ActivitiesViewModel`. Loads the workouts and
/// planned workouts for the scaffold's current period.
class ActivitiesNotifier extends Notifier<ActivitiesState> {
  int _generation = 0;

  @override
  ActivitiesState build() => ActivitiesState(selectedDate: LocalDate.now());

  Future<void> load(PeriodSelection selection) async {
    final generation = ++_generation;
    final prefs = ref.read(preferencesRepositoryProvider);
    final repo = ref.read(activityRepositoryProvider);

    state = state.copyWith(
      selectedRange: selection.selectedRange,
      selectedDate: selection.selectedDate,
      isLoading: true,
      error: null,
    );

    final period = displayPeriodFor(
      selection.selectedRange,
      selection.selectedDate,
      weekPeriodMode: prefs.weekPeriodMode,
    );

    try {
      final results = await (
        repo.loadWorkouts(period.start, period.end),
        repo.loadPlannedWorkouts(period.start, period.end),
      ).wait;
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        workouts: results.$1,
        plannedWorkouts: results.$2,
        error: null,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        error:
            throwableToScreenError(error, fallback: 'Unable to load workouts.'),
      );
    }
  }

  Future<void> refresh() =>
      load(PeriodSelection(state.selectedRange, state.selectedDate));
}

final activitiesNotifierProvider =
    NotifierProvider<ActivitiesNotifier, ActivitiesState>(
  ActivitiesNotifier.new,
);
