import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/period/period_range_preference_key.dart';
import '../../core/period/time_range.dart';
import '../../core/presentation/display_value.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../di/providers.dart';
import '../../domain/insights/daily_goals.dart';
import '../../domain/model/nutrition_models.dart';
import '../../state/app_providers.dart';
import '../../ui/charts/period_chart.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/metric_card.dart';
import '../../ui/components/metric_detail_scaffold.dart';
import '../../ui/components/ov_card.dart';
import '../../health/health_permissions.dart';
import 'nutrition_formatting.dart';
import 'nutrition_metric.dart';
import 'nutrition_notifier.dart';

/// The shared period-detail screen for the four keyed nutrition metrics
/// (calories-in / protein / carbs / fat), ported from the Kotlin
/// `NutritionMetricScreen` + `nutritionMetricContent`.
class NutritionMetricScreen extends ConsumerWidget {
  const NutritionMetricScreen({super.key, required this.metric});

  final NutritionMetric metric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = nutritionMetricProvider(metric);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final formatter = ref.watch(unitFormatterProvider);
    final weekMode = ref.watch(preferencesRepositoryProvider).weekPeriodMode;
    final syncPaused = !ref.watch(healthConnectSyncEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(metric.title)),
      body: HealthConnectGate(
        requiredPermissions: {HcPermissions.readNutrition},
        showInlineSyncBanner: false,
        child: MetricDetailScaffold(
          rangePreferenceKey: PeriodRangePreferenceKey.nutrition,
          onRefresh: notifier.refresh,
          isLoading: state.isLoading,
          screenError: state.error,
          weekPeriodMode: weekMode,
          syncPaused: syncPaused,
          onSelectionChanged: (selection) => notifier.load(selection),
          content: (period) => _content(context, metric, state, formatter, period),
        ),
      ),
    );
  }
}

List<Widget> _content(
  BuildContext context,
  NutritionMetric metric,
  NutritionState state,
  UnitFormatter formatter,
  DatePeriod period,
) {
  if (!state.hasData) {
    if (state.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    return [
      _padded(
        MetricCardPlaceholder(
          title: metric.title,
          icon: metric.icon,
          accentColor: metric.accentColor,
          message: 'No nutrition logged for this period.',
        ),
      ),
    ];
  }

  final nutrient = metric.nutrient;
  final values = [
    for (final day in state.dailyMacros)
      PeriodChartValue(day.date, day.valueFor(nutrient)),
  ];
  final rawValues = values.map((value) => value.value).toList();
  final total = rawValues.fold<double>(0.0, (sum, value) => sum + value);
  final loggedDays = rawValues.where((value) => value > 0.0).length;
  final average = loggedDays > 0 ? total / loggedDays : 0.0;
  final best = rawValues.fold<double>(0.0, (m, value) => math.max(m, value));

  DisplayValue format(double value) =>
      nutrientDisplayValue(nutrient, value, formatter);
  final totalDisplay = format(total);

  final goalProgress = dailyGoalProgress(
    [for (final value in values) DailyGoalValue(date: value.date, value: value.value)],
    period,
    state.dailyGoal,
    metric.dailyGoalKey.direction,
  );

  return [
    _padded(
      MetricCard(
        title: metric.title,
        value: totalDisplay.value,
        unit: totalDisplay.unit,
        icon: metric.icon,
        accentColor: metric.accentColor,
        subtitle: state.entries.isNotEmpty
            ? '${formatter.count(state.entries.length)} entries'
            : 'Across the selected period',
      ),
    ),
    _padded(
      MetricBarChart(
        title: metric.title,
        values: values,
        selectedRange: state.selectedRange,
        period: period,
        accentColor: metric.accentColor,
        summaryValue: totalDisplay.text,
        valueFormatter: (value) => format(value).text,
      ),
    ),
    _padded(
      _NutritionGoalCard(
        goal: format(state.dailyGoal),
        progress: goalProgress,
        accentColor: metric.accentColor,
      ),
    ),
    const SectionHeader('Statistics'),
    _padded(
      _NutritionStatisticsCard(
        rows: [
          ('Total', totalDisplay),
          ('Daily average', format(average)),
          ('Best day', format(best)),
          ('Logged days', DisplayValue('$loggedDays', 'days')),
        ],
        accentColor: metric.accentColor,
      ),
    ),
  ];
}

Widget _padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: child,
    );

class _NutritionGoalCard extends StatelessWidget {
  const _NutritionGoalCard({
    required this.goal,
    required this.progress,
    required this.accentColor,
  });

  final DisplayValue goal;
  final DailyGoalProgress progress;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final directionLabel =
        progress.direction == DailyGoalDirection.atMost ? 'at most' : 'at least';
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: accentColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily goal', style: theme.textTheme.titleSmall),
                      Text(
                        '${progress.goalMetDays} of ${progress.trackedDays} days met · '
                        '${progress.successRatePercent}%',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: goal.value,
                        style: theme.textTheme.titleLarge,
                      ),
                      TextSpan(
                        text: ' ${goal.unit}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Target: $directionLabel ${goal.text} per day.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionStatisticsCard extends StatelessWidget {
  const _NutritionStatisticsCard({required this.rows, required this.accentColor});

  final List<(String, DisplayValue)> rows;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                      ?.copyWith(color: scheme.onSurfaceVariant),
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
                        color: scheme.onSurface,
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

// ── Route-facing per-metric wrappers (Kotlin `CaloriesInScreen`, …). ──────────

class CaloriesInScreen extends StatelessWidget {
  const CaloriesInScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const NutritionMetricScreen(metric: NutritionMetric.caloriesIn);
}

class ProteinScreen extends StatelessWidget {
  const ProteinScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const NutritionMetricScreen(metric: NutritionMetric.protein);
}

class CarbsScreen extends StatelessWidget {
  const CarbsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const NutritionMetricScreen(metric: NutritionMetric.carbs);
}

class FatScreen extends StatelessWidget {
  const FatScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const NutritionMetricScreen(metric: NutritionMetric.fat);
}
