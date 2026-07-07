import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/period/period_load_query.dart';
import '../../core/period/time_range.dart';
import '../../core/presentation/display_value.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../core/time/local_date.dart';
import '../../di/providers.dart';
import '../../domain/usecase/load_heart_period_use_case.dart';
import '../../health/health_permissions.dart';
import '../../navigation/app_routes.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/metric_card.dart';
import '../../ui/components/ov_card.dart';
import '../heart/heart_metric.dart';

/// Loads the combined heart + vitals period (this week) for the overview.
/// Autodispose so it re-runs each time the screen is opened; invalidated by the
/// pull-to-refresh.
final _heartVitalsOverviewProvider =
    FutureProvider.autoDispose<HeartPeriodLoadResult>((ref) async {
  final prefs = ref.read(preferencesRepositoryProvider);
  final useCase = ref.read(loadHeartPeriodUseCaseProvider);
  final query = PeriodLoadQuery(
    range: TimeRange.week,
    anchorDate: LocalDate.now(),
    weekPeriodMode: prefs.weekPeriodMode,
  );
  return useCase(query, const HeartPeriodLoadCombined());
});

/// The combined heart & vitals overview (`/heart_vitals`), a trimmed port of the
/// Kotlin `HeartVitalsOverviewScreen`: a hub of latest heart + vitals readings,
/// each tile opening the corresponding metric detail screen.
class HeartVitalsOverviewScreen extends ConsumerWidget {
  const HeartVitalsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(unitFormatterProvider);
    final async = ref.watch(_heartVitalsOverviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Heart & Vitals')),
      body: HealthConnectGate(
        requiredPermissions: {
          HcPermissions.readHeartRate,
          HcPermissions.readRestingHeartRate,
          HcPermissions.readHrv,
        },
        showInlineSyncBanner: false,
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_heartVitalsOverviewProvider),
          child: async.when(
            loading: () => ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            ),
            error: (error, _) => ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Unable to load heart & vitals.\n$error'),
                ),
              ],
            ),
            data: (result) => _overview(context, result, formatter),
          ),
        ),
      ),
    );
  }
}

Widget _overview(
  BuildContext context,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
) {
  final vitals = result.vitalsSummary();
  final latestSummary = result.dailySummaries.isEmpty
      ? null
      : result.dailySummaries.reduce((a, b) => b.date.isAfter(a.date) ? b : a);
  final latestResting = result.dailyRestingHR.isEmpty
      ? null
      : result.dailyRestingHR.reduce((a, b) => b.date.isAfter(a.date) ? b : a);
  final latestHrv = result.dailyHrv.isEmpty
      ? null
      : result.dailyHrv.reduce((a, b) => b.date.isAfter(a.date) ? b : a);

  final tiles = <Widget>[
    _tile(
      context,
      HeartMetric.averageHeartRate,
      latestSummary == null ? null : formatter.heartRate(latestSummary.avgBpm),
    ),
    _tile(
      context,
      HeartMetric.restingHeartRate,
      latestResting == null ? null : formatter.heartRate(latestResting.bpm),
    ),
    _tile(
      context,
      HeartMetric.hrv,
      latestHrv == null ? null : formatter.hrv(latestHrv.rmssdMs),
    ),
    _tile(
      context,
      HeartMetric.bloodPressure,
      vitals.latestBloodPressure == null
          ? null
          : formatter.bloodPressure(vitals.latestBloodPressure!.systolicMmHg,
              vitals.latestBloodPressure!.diastolicMmHg),
    ),
    _tile(
      context,
      HeartMetric.spo2,
      vitals.latestSpO2 == null
          ? null
          : formatter.percent(vitals.latestSpO2!.percent),
    ),
    _tile(
      context,
      HeartMetric.respiratoryRate,
      vitals.latestRespiratoryRate == null
          ? null
          : formatter.respiratoryRate(
              vitals.latestRespiratoryRate!.breathsPerMinute),
    ),
    _tile(
      context,
      HeartMetric.bodyTemperature,
      vitals.latestBodyTemperature == null
          ? null
          : formatter.temperature(
              vitals.latestBodyTemperature!.temperatureCelsius),
    ),
    _tile(
      context,
      HeartMetric.vo2Max,
      vitals.latestVo2Max == null
          ? null
          : formatter.vo2Max(vitals.latestVo2Max!.vo2MaxMlPerKgPerMin),
    ),
    _tile(
      context,
      HeartMetric.bloodGlucose,
      vitals.latestBloodGlucose == null
          ? null
          : formatter.bloodGlucose(vitals.latestBloodGlucose!.millimolesPerLiter),
    ),
  ];

  return ListView(
    padding: const EdgeInsets.symmetric(vertical: 8),
    children: [
      for (final tile in tiles)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: tile,
        ),
      const SizedBox(height: 16),
    ],
  );
}


Widget _tile(
  BuildContext context,
  HeartMetric metric,
  DisplayValue? value,
) {
  final theme = Theme.of(context);
  return OpenVitalsCard(
    onTap: () => context.push(AppRoutes.metricLocation(metric.routeName)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(metric.icon, color: metric.accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(metric.title, style: theme.textTheme.bodyLarge),
          ),
          if (value != null)
            MetricValueRow(value: value.value, unit: value.unit)
          else
            Text(
              'No data',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    ),
  );
}
