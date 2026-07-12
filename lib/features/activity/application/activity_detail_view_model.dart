import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/presentation/screen_error.dart';
import '../../../core/result/result.dart';
import '../../../di/providers.dart';
import '../../../domain/insights/activity_splits.dart';
import '../../../domain/model/activity_models.dart';
import '../../../domain/model/heart_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/app_providers.dart';
import 'activity_detail_display.dart';
import 'activity_navigation_display.dart';

part 'activity_detail_view_model.freezed.dart';

/// The Riverpod port of the Kotlin `ActivityDetailUiState` — a single workout
/// plus its in-session heart-rate, speed and cadence samples, the splits derived
/// from them, and the precomputed [ActivityDetailDisplay] the cards render.
@freezed
abstract class ActivityDetailState with _$ActivityDetailState {
  const ActivityDetailState._();

  const factory ActivityDetailState({
    @Default(true) bool isLoading,
    ScreenError? error,
    ExerciseData? workout,
    @Default(<HeartRateSample>[]) List<HeartRateSample> heartRateSamples,
    @Default(<SpeedSample>[]) List<SpeedSample> speedSamples,
    @Default(<ActivityCadenceSample>[])
    List<ActivityCadenceSample> cadenceSamples,
    @Default(ActivitySplits.none()) ActivitySplits splits,
    ActivityDetailDisplay? display,

    /// The CoMaps guidance saved while this activity was recorded, already
    /// turned into the lines the Navigation section prints. Empty for every
    /// activity that was not recorded with CoMaps guiding — which is most.
    @Default(<ActivityNavigationRow>[])
    List<ActivityNavigationRow> navigationRows,
  }) = _ActivityDetailState;
}

/// The Riverpod port of the Kotlin `ActivityDetailViewModel`.
///
/// One instance per detail screen: the screen creates an auto-dispose provider
/// bound to its `activityId` (so two stacked detail screens stay independent),
/// and [build] kicks off the first load. The marker/route-backfill slices the
/// Kotlin loads are still out of scope.
class ActivityDetailViewModel extends Notifier<ActivityDetailState> {
  ActivityDetailViewModel(this.activityId);

  final String activityId;
  int _generation = 0;

  @override
  ActivityDetailState build() {
    // The split distance is a user preference: changing it in settings must
    // re-cut the splits of a detail screen that is already open.
    ref.watch(activitySplitDistanceMetersProvider);
    Future.microtask(() {
      if (ref.mounted) _load();
    });
    return const ActivityDetailState();
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (activityId.isEmpty) {
      state = const ActivityDetailState(
        isLoading: false,
        error: ScreenErrorMissingArgument(),
      );
      return;
    }

    final generation = ++_generation;
    final loadActivityDetail = ref.read(loadActivityDetailUseCaseProvider);
    final splitDistanceMeters = ref.read(activitySplitDistanceMetersProvider);
    state = state.copyWith(isLoading: true, error: null);

    // Reassembling the workout — which repositories to ask, in what order, and
    // that Health Connect's own totals outrank the ones derived from samples —
    // is domain knowledge, and lives in the use case. What stays here is the
    // view's business: the generation guard, and turning a result into state.
    final result = await loadActivityDetail(activityId);
    if (!ref.mounted || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        if (value == null) {
          state = const ActivityDetailState(
            isLoading: false,
            error: ScreenErrorNotFound(),
          );
          return;
        }
        // Splits depend on a user preference, so they are cut here rather than in
        // the use case: changing the split distance must re-cut an open screen.
        final splits = computeActivitySplits(
          workout: value.workout,
          heartRateSamples: value.heartRateSamples,
          speedSamples: value.speedSamples,
          splitDistanceMeters: splitDistanceMeters,
        );
        // App-local history, so it is fetched separately from the workout: the
        // use case reassembles what Health Connect knows, and Health Connect has
        // never heard of CoMaps.
        final navigationRows = await _loadNavigationRows();
        if (!ref.mounted || generation != _generation) return;
        state = ActivityDetailState(
          isLoading: false,
          workout: value.workout,
          heartRateSamples: value.heartRateSamples,
          speedSamples: value.speedSamples,
          cadenceSamples: value.cadenceSamples,
          splits: splits,
          display: buildActivityDetailDisplay(
            workout: value.workout,
            cadenceSamples: value.cadenceSamples,
            splits: splits,
          ),
          navigationRows: navigationRows,
        );
      case Err(:final failure):
        state = ActivityDetailState(
          isLoading: false,
          error: failure.toScreenError(fallback: 'Unable to load activity.'),
        );
    }
  }

  /// The saved CoMaps guidance, as rows. A failure here is NOT a failure of the
  /// screen: the activity is the point, the guidance was a bonus while it was
  /// recorded, and its absence reads exactly like never having had any.
  Future<List<ActivityNavigationRow>> _loadNavigationRows() async {
    final result = await ref
        .read(coMapsNavigationRepositoryProvider)
        .loadSamples(activityId);
    return switch (result) {
      Ok(:final value) => buildActivityNavigationRows(value, _localizations()),
      Err() => const <ActivityNavigationRow>[],
    };
  }

  /// The localizations the row builder needs, resolved without a
  /// `BuildContext` — the rows are derived here, off the widget tree. Mirrors
  /// the dashboard view-model's choice: the selected language, or the platform
  /// locale when it is `system`.
  AppLocalizations _localizations() {
    final tag = ref.read(appLanguageProvider).languageTag;
    final locale =
        tag != null ? Locale(tag) : PlatformDispatcher.instance.locale;
    try {
      return lookupAppLocalizations(locale);
    } on FlutterError {
      return lookupAppLocalizations(const Locale('en'));
    }
  }
}
