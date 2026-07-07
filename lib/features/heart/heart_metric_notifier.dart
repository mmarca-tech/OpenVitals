import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/period/period_load_query.dart';
import '../../core/period/period_selection.dart';
import '../../core/period/time_range.dart';
import '../../core/presentation/screen_error.dart';
import '../../core/time/local_date.dart';
import '../../di/providers.dart';
import '../../domain/model/refresh_mode.dart';
import '../../domain/usecase/load_heart_period_use_case.dart';
import 'heart_metric.dart';

part 'heart_metric_notifier.freezed.dart';

/// The Riverpod port of the Kotlin `HeartUiState`, trimmed to the selection the
/// scaffold drives, the loaded [HeartPeriodLoadResult] payload, and loading/
/// error flags. The Kotlin view-model precomputes a `HeartDisplayState`; here the
/// (cheap) per-metric derivations are computed on demand by the screen.
@freezed
abstract class HeartMetricState with _$HeartMetricState {
  const HeartMetricState._();

  const factory HeartMetricState({
    required LocalDate selectedDate,
    @Default(TimeRange.week) TimeRange selectedRange,
    @Default(true) bool isLoading,
    ScreenError? error,
    HeartPeriodLoadResult? result,
  }) = _HeartMetricState;
}

/// The Riverpod port of the Kotlin `HeartViewModel`, shared across the ten heart
/// + vitals metrics (keyed by [metric]).
///
/// A manual [Notifier] (no codegen), matching the activity template: the owning
/// [MetricDetailScaffold] drives every load through [load] and pull-to-refresh
/// through [refresh]. A monotonic [_generation] guard drops stale results.
class HeartMetricNotifier extends Notifier<HeartMetricState> {
  HeartMetricNotifier(this.metric);

  final HeartMetric metric;
  int _generation = 0;

  @override
  HeartMetricState build() =>
      HeartMetricState(selectedDate: LocalDate.now());

  Future<void> load(
    PeriodSelection selection, {
    RefreshMode refreshMode = RefreshMode.normal,
  }) async {
    final generation = ++_generation;
    final prefs = ref.read(preferencesRepositoryProvider);
    final useCase = ref.read(loadHeartPeriodUseCaseProvider);

    state = state.copyWith(
      selectedRange: selection.selectedRange,
      selectedDate: selection.selectedDate,
      isLoading: true,
      error: null,
    );

    final query = PeriodLoadQuery(
      range: selection.selectedRange,
      anchorDate: selection.selectedDate,
      weekPeriodMode: prefs.weekPeriodMode,
    );

    try {
      final result = await useCase(
        query,
        metric.loadRequest,
        refreshMode: refreshMode,
      );
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(isLoading: false, result: result, error: null);
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        error: throwableToScreenError(error, fallback: 'Unable to load data.'),
      );
    }
  }

  Future<void> refresh() => load(
        PeriodSelection(state.selectedRange, state.selectedDate),
        refreshMode: RefreshMode.force,
      );
}

/// One [NotifierProvider] per heart/vitals metric, built eagerly so each metric's
/// state survives across screen rebuilds.
final Map<HeartMetric,
        NotifierProvider<HeartMetricNotifier, HeartMetricState>>
    _heartMetricProviders = {
  for (final metric in HeartMetric.values)
    metric: NotifierProvider<HeartMetricNotifier, HeartMetricState>(
      () => HeartMetricNotifier(metric),
    ),
};

/// The state provider for [metric]'s period detail screen.
NotifierProvider<HeartMetricNotifier, HeartMetricState> heartMetricProvider(
  HeartMetric metric,
) =>
    _heartMetricProviders[metric]!;
