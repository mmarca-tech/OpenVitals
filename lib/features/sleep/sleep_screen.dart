import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/period/period_range_preference_key.dart';
import '../../core/period/period_titles.dart';
import '../../core/period/time_range.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../di/providers.dart';
import '../../domain/model/sleep_models.dart';
import '../../health/health_permissions.dart';
import '../../state/app_providers.dart';
import '../../ui/charts/period_chart.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/metric_detail_scaffold.dart';
import '../../ui/theme/app_colors.dart';
import 'sleep_cards.dart';
import 'sleep_notifier.dart';
import 'sleep_presentation.dart';

/// The sleep period-detail screen, ported from the Kotlin `SleepScreen`.
///
/// Day view shows the single-night stage timeline, stage share, overview
/// (score/duration/schedule/efficiency) and statistics; week/month/year show the
/// overview, a per-night duration bar chart, stage share and statistics. Wrapped
/// in [HealthConnectGate] with the sleep read permission and driven by
/// [MetricDetailScaffold] (SLEEP range key).
class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sleepNotifierProvider);
    final notifier = ref.read(sleepNotifierProvider.notifier);
    final formatter = ref.watch(unitFormatterProvider);
    final weekMode = ref.watch(preferencesRepositoryProvider).weekPeriodMode;
    final syncPaused = !ref.watch(healthConnectSyncEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sleep')),
      body: HealthConnectGate(
        requiredPermissions: {HcPermissions.readSleep},
        showInlineSyncBanner: false,
        child: MetricDetailScaffold(
          rangePreferenceKey: PeriodRangePreferenceKey.sleep,
          onRefresh: notifier.refresh,
          isLoading: state.isLoading,
          screenError: state.error,
          weekPeriodMode: weekMode,
          syncPaused: syncPaused,
          onSelectionChanged: (selection) => notifier.load(selection),
          content: (period) => _content(context, state, formatter, period),
        ),
      ),
    );
  }
}

List<Widget> _content(
  BuildContext context,
  SleepState state,
  UnitFormatter formatter,
  DatePeriod period,
) {
  final result = state.result;
  if (result == null) {
    if (state.isLoading) return const [_LoadingBlock()];
    return const [_SleepMessage('No sleep data for this period.')];
  }

  final display = buildSleepDisplay(
    result: result,
    selectedRange: state.selectedRange,
    selectedDate: state.selectedDate,
    sleepRangeMode: state.sleepRangeMode,
    weekPeriodMode: state.weekPeriodMode,
  );
  final title = periodTitle(state.selectedRange, period);

  if (state.selectedRange == TimeRange.day) {
    final summary = display.dailySummary;
    if (summary == null) {
      if (state.isLoading) return const [_LoadingBlock()];
      return const [_SleepMessage('No sleep recorded for the selected day.')];
    }
    return [
      _padded(SleepSessionTimelineCard(
        session: summary,
        formatter: formatter,
        timeRangeText: _dayTimeRangeText(display.dailySessions),
      )),
      _padded(SleepOverviewCard(
        summary: display.overviewSummary,
        formatter: formatter,
        periodTitle: title,
      )),
      _padded(SleepStageShareCard(
        summary: display.overviewSummary,
        formatter: formatter,
      )),
      _padded(SleepStatisticsCard(
        durationPoints: display.durationPoints,
        formatter: formatter,
      )),
    ];
  }

  if (result.sessions.isEmpty) {
    if (state.isLoading) return const [_LoadingBlock()];
    return const [_SleepMessage('No sleep recorded for this period.')];
  }

  final nights = display.durationPoints.where((p) => p.hours > 0.0).toList();
  final averageHours =
      nights.isEmpty ? 0.0 : nights.map((p) => p.hours).reduce((a, b) => a + b) / nights.length;
  final summaryValue =
      'Avg ${formatter.decimal(averageHours, 1)}h · ${nights.length} nights';

  return [
    _padded(SleepOverviewCard(
      summary: display.overviewSummary,
      formatter: formatter,
      periodTitle: title,
    )),
    _padded(MetricBarChart(
      title: 'Sleep',
      values: [
        for (final point in display.durationPoints)
          PeriodChartValue(point.date, point.hours),
      ],
      selectedRange: state.selectedRange,
      period: period,
      accentColor: AppColors.sleep,
      accentAlpha: 0.75,
      summaryValue: summaryValue,
      yearAggregation: PeriodBarAggregation.averageNonZero,
      valueFormatter: (value) => '${formatter.decimal(value, 1)}h',
    )),
    _padded(SleepStageShareCard(
      summary: display.overviewSummary,
      formatter: formatter,
    )),
    _padded(SleepStatisticsCard(
      durationPoints: display.durationPoints,
      formatter: formatter,
    )),
  ];
}

final DateFormat _timeFormat = DateFormat('HH:mm');

String? _dayTimeRangeText(List<SleepData> sessions) {
  if (sessions.isEmpty) return null;
  final sorted = [...sessions]
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  return sorted
      .map((s) =>
          '${_timeFormat.format(s.startTime.toLocal())} - ${_timeFormat.format(s.endTime.toLocal())}')
      .join(' | ');
}

Widget _padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: child,
    );

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _SleepMessage extends StatelessWidget {
  const _SleepMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
