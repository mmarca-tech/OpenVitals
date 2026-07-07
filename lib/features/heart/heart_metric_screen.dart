import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/period/period_range_preference_key.dart';
import '../../di/providers.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/metric_detail_scaffold.dart';
import 'heart_metric.dart';
import 'heart_metric_content.dart';
import 'heart_metric_notifier.dart';

/// The shared period-detail screen for the ten heart + vitals metrics, ported
/// from the Kotlin `HeartMetricScreen`. Each route-facing screen (`HeartRate
/// Screen`, `BloodPressureScreen`, …) is a thin wrapper that fixes [metric].
/// Wrapped in [HealthConnectGate] with the metric's read permission and driven
/// by [MetricDetailScaffold] (HEART range key).
class HeartMetricScreen extends ConsumerWidget {
  const HeartMetricScreen({super.key, required this.metric});

  final HeartMetric metric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = heartMetricProvider(metric);
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
          // The Kotlin `HeartViewModel` keys every heart/vitals metric's
          // remembered range on `PeriodRangePreferenceKey.HEART`.
          rangePreferenceKey: PeriodRangePreferenceKey.heart,
          onRefresh: notifier.refresh,
          isLoading: state.isLoading,
          screenError: state.error,
          weekPeriodMode: weekMode,
          syncPaused: syncPaused,
          onSelectionChanged: (selection) => notifier.load(selection),
          content: (period) =>
              heartMetricContent(metric, state, formatter, period),
        ),
      ),
    );
  }
}

// ── Route-facing per-metric wrappers (Kotlin `HeartRateScreen`, …). ──────────

class HeartRateScreen extends StatelessWidget {
  const HeartRateScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const HeartMetricScreen(metric: HeartMetric.averageHeartRate);
}

class RestingHeartRateScreen extends StatelessWidget {
  const RestingHeartRateScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const HeartMetricScreen(metric: HeartMetric.restingHeartRate);
}

class HrvScreen extends StatelessWidget {
  const HrvScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const HeartMetricScreen(metric: HeartMetric.hrv);
}
