import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/period/period_range_preference_key.dart';
import '../../core/period/time_range.dart';
import '../../core/presentation/display_value.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../di/providers.dart';
import '../../state/app_providers.dart';
import '../../ui/charts/period_chart.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/metric_card.dart';
import '../../ui/components/metric_detail_scaffold.dart';
import '../../ui/components/ov_card.dart';
import 'activity_metric.dart';
import 'activity_metric_notifier.dart';

/// The shared period-detail screen for the six movement metrics, ported from the
/// Kotlin `ActivityMetricScreen` (`ActivityScreen.kt`). Each route-facing screen
/// (`StepsScreen`, `DistanceScreen`, …) is a thin wrapper that fixes [metric];
/// the metric-specific composition (accent, formatting, which slice to chart)
/// lives on [ActivityMetric].
class ActivityMetricScreen extends ConsumerWidget {
  const ActivityMetricScreen({super.key, required this.metric});

  final ActivityMetric metric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = activityMetricProvider(metric);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final formatter = ref.watch(unitFormatterProvider);
    final weekMode = ref.watch(preferencesRepositoryProvider).weekPeriodMode;
    final syncPaused = !ref.watch(healthConnectSyncEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(metric.title)),
      body: HealthConnectGate(
        requiredPermissions: {metric.readPermission},
        showInlineSyncBanner: false,
        child: MetricDetailScaffold(
          // The Kotlin `ActivityViewModel` keys every movement metric's
          // remembered range on `PeriodRangePreferenceKey.STEPS`.
          rangePreferenceKey: PeriodRangePreferenceKey.steps,
          onRefresh: notifier.refresh,
          isLoading: state.isLoading,
          screenError: state.error,
          weekPeriodMode: weekMode,
          syncPaused: syncPaused,
          onSelectionChanged: (selection) => notifier.load(selection),
          content: (period) =>
              _content(context, metric, state, formatter, period),
        ),
      ),
    );
  }
}

List<Widget> _content(
  BuildContext context,
  ActivityMetric metric,
  ActivityMetricState state,
  UnitFormatter formatter,
  DatePeriod period,
) {
  final data = state.data;
  if (data == null) {
    if (state.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    return [_placeholder(metric)];
  }

  final values = metric.chartValues(data);
  final hasData = values.any((value) => value.value > 0.0);
  if (!hasData) return [_placeholder(metric)];

  final total = values.fold<double>(0.0, (sum, value) => sum + value.value);
  final activeDays = values.where((value) => value.value > 0.0).length;
  final average = activeDays > 0 ? total / activeDays : 0.0;
  final best = values.fold<double>(0.0, (m, value) => math.max(m, value.value));
  final heroValue = metric.format(formatter, total);

  return [
    _padded(
      MetricCard(
        title: metric.title,
        value: heroValue.value,
        unit: heroValue.unit,
        icon: metric.icon,
        accentColor: metric.accentColor,
        subtitle: activeDays == 1 ? '1 active day' : '$activeDays active days',
      ),
    ),
    _padded(
      MetricBarChart(
        title: metric.title,
        values: values,
        selectedRange: state.selectedRange,
        period: period,
        accentColor: metric.accentColor,
        summaryValue: heroValue.text,
        valueFormatter: (value) => metric.formatChartValue(formatter, value),
      ),
    ),
    _padded(
      _ActivityStatisticsCard(
        rows: [
          ('Total', metric.format(formatter, total)),
          ('Daily average', metric.format(formatter, average)),
          ('Best day', metric.format(formatter, best)),
        ],
        accentColor: metric.accentColor,
      ),
    ),
  ];
}

Widget _placeholder(ActivityMetric metric) => _padded(
      MetricCardPlaceholder(
        title: metric.title,
        icon: metric.icon,
        accentColor: metric.accentColor,
        message: metric.emptyMessage,
      ),
    );

Widget _padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: child,
    );

/// A small total / average / best statistics card. A trimmed port of the Kotlin
/// activity statistics section.
class _ActivityStatisticsCard extends StatelessWidget {
  const _ActivityStatisticsCard({required this.rows, required this.accentColor});

  final List<(String, DisplayValue)> rows;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Statistics',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.$1, style: theme.textTheme.bodyMedium),
                    Text(
                      row.$2.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Route-facing per-metric wrappers (Kotlin `StepsScreen`, `DistanceScreen`, …).

class StepsScreen extends StatelessWidget {
  const StepsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ActivityMetricScreen(metric: ActivityMetric.steps);
}

class DistanceScreen extends StatelessWidget {
  const DistanceScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ActivityMetricScreen(metric: ActivityMetric.distance);
}

class CaloriesOutScreen extends StatelessWidget {
  const CaloriesOutScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ActivityMetricScreen(metric: ActivityMetric.caloriesOut);
}

class ActiveCaloriesScreen extends StatelessWidget {
  const ActiveCaloriesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ActivityMetricScreen(metric: ActivityMetric.activeCalories);
}

class FloorsScreen extends StatelessWidget {
  const FloorsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ActivityMetricScreen(metric: ActivityMetric.floors);
}

class ElevationScreen extends StatelessWidget {
  const ElevationScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ActivityMetricScreen(metric: ActivityMetric.elevation);
}

class WheelchairScreen extends StatelessWidget {
  const WheelchairScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ActivityMetricScreen(metric: ActivityMetric.wheelchair);
}
