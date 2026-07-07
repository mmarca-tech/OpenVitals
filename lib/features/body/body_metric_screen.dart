import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/period/period_range_preference_key.dart';
import '../../di/providers.dart';
import '../../navigation/app_routes.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/metric_card.dart';
import '../../ui/components/metric_detail_scaffold.dart';
import 'body_metric.dart';
import 'body_metric_content.dart';
import 'body_metric_notifier.dart';

/// The shared body detail screen for the nine body-composition metrics, ported
/// from the Kotlin `BodyMetricScreen`. Each route-facing screen (`WeightScreen`,
/// `HeightScreen`, …) is a thin wrapper that fixes [metric]. Wrapped in a
/// [HealthConnectGate] with the metric's read permission and driven by a
/// [MetricDetailScaffold] (BODY range key).
class BodyMetricScreen extends ConsumerWidget {
  const BodyMetricScreen({super.key, required this.metric});

  final BodyMetric metric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bodyMetricNotifierProvider);
    final notifier = ref.read(bodyMetricNotifierProvider.notifier);
    final formatter = ref.watch(unitFormatterProvider);
    final weekMode = ref.watch(preferencesRepositoryProvider).weekPeriodMode;
    final syncPaused = !ref.watch(healthConnectSyncEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(metric.title)),
      body: HealthConnectGate(
        requiredPermissions: {metric.readPermission},
        showInlineSyncBanner: false,
        child: MetricDetailScaffold(
          // The Kotlin `BodyViewModel` keys every body metric's remembered range
          // on `PeriodRangePreferenceKey.BODY` (default MONTH).
          rangePreferenceKey: PeriodRangePreferenceKey.body,
          onRefresh: notifier.refresh,
          isLoading: state.isLoading,
          screenError: state.error,
          weekPeriodMode: weekMode,
          syncPaused: syncPaused,
          onSelectionChanged: (selection) => notifier.load(selection),
          content: (period) =>
              bodyMetricContent(metric, state, formatter, period),
        ),
      ),
    );
  }
}

/// The `/body` measurements section overview. Renders a latest-value card per
/// body metric (a trimmed port of the Kotlin `bodyContent` overview), each
/// tapping through to its detail screen.
class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bodyMetricNotifierProvider);
    final notifier = ref.read(bodyMetricNotifierProvider.notifier);
    final formatter = ref.watch(unitFormatterProvider);
    final weekMode = ref.watch(preferencesRepositoryProvider).weekPeriodMode;
    final syncPaused = !ref.watch(healthConnectSyncEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Body')),
      body: HealthConnectGate(
        requiredPermissions: {BodyMetric.weight.readPermission},
        showInlineSyncBanner: false,
        child: MetricDetailScaffold(
          rangePreferenceKey: PeriodRangePreferenceKey.body,
          onRefresh: notifier.refresh,
          isLoading: state.isLoading,
          screenError: state.error,
          weekPeriodMode: weekMode,
          syncPaused: syncPaused,
          onSelectionChanged: (selection) => notifier.load(selection),
          content: (period) {
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
              return const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: MetricCardPlaceholder(
                    title: 'Body',
                    icon: Icons.monitor_weight_outlined,
                    accentColor: Color(0xFFFF9800),
                    message: 'No body measurements for this period.',
                  ),
                ),
              ];
            }
            return [
              for (final (metric, value) in bodyOverviewValues(data, formatter))
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: value == null
                      ? MetricCardPlaceholder(
                          title: metric.title,
                          icon: metric.icon,
                          accentColor: metric.accentColor,
                          message: metric.emptyMessage,
                          onTap: () => context.push(
                            AppRoutes.metricLocation(metric.routeName),
                          ),
                        )
                      : MetricCard(
                          title: metric.title,
                          value: value.value,
                          unit: value.unit,
                          icon: metric.icon,
                          accentColor: metric.accentColor,
                          onTap: () => context.push(
                            AppRoutes.metricLocation(metric.routeName),
                          ),
                        ),
                ),
            ];
          },
        ),
      ),
    );
  }
}

// ── Route-facing per-metric wrappers (Kotlin `WeightScreen`, …). ─────────────

class WeightScreen extends StatelessWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const BodyMetricScreen(metric: BodyMetric.weight);
}

class HeightScreen extends StatelessWidget {
  const HeightScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const BodyMetricScreen(metric: BodyMetric.height);
}

class BmiScreen extends StatelessWidget {
  const BmiScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const BodyMetricScreen(metric: BodyMetric.bmi);
}
