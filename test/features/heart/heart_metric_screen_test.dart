import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/core/period/period_load_query.dart';
import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/data/repository/contract/heart_repository.dart';
import 'package:openvitals/data/repository/contract/vitals_repository.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/domain/model/heart_models.dart';
import 'package:openvitals/domain/model/refresh_mode.dart';
import 'package:openvitals/domain/query/heart_period_data.dart';
import 'package:openvitals/domain/query/vitals_period_data.dart';
import 'package:openvitals/features/heart/heart_metric_screen.dart';
import 'package:openvitals/health/health_permissions.dart';
import 'package:openvitals/ui/charts/line_chart.dart';
import 'package:openvitals/ui/components/health_connect_gate.dart';
import 'package:openvitals/ui/components/metric_card.dart';

class _FakeHeartRepository implements HeartRepository {
  _FakeHeartRepository({this.summaries = const <HeartRateSummary>[]});

  final List<HeartRateSummary> summaries;

  @override
  Future<HeartPeriodData> loadHeartPeriod(
    PeriodLoadQuery query,
    HeartPeriodMetric metric, {
    RefreshMode refreshMode = RefreshMode.normal,
  }) async =>
      HeartPeriodData(dailySummaries: summaries);

  @override
  Future<List<DailyHrv>> loadDailyHRV(LocalDate start, LocalDate end) async =>
      const <DailyHrv>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVitalsRepository implements VitalsRepository {
  @override
  Set<String> get phase3Permissions => const <String>{};

  @override
  Future<VitalsPeriodData> loadVitalsPeriod(
    PeriodLoadQuery query,
    VitalsPeriodMetric metric, {
    RefreshMode refreshMode = RefreshMode.normal,
  }) async =>
      const VitalsPeriodData();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HeartRateSummary _summary(LocalDate date, int avg) => HeartRateSummary(
      date: date,
      avgBpm: avg,
      minBpm: avg - 10,
      maxBpm: avg + 20,
    );

Future<Widget> _bootstrap({
  required _FakeHeartRepository heartRepository,
  required Set<String> granted,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      heartRepositoryProvider.overrideWithValue(heartRepository),
      vitalsRepositoryProvider.overrideWithValue(_FakeVitalsRepository()),
      healthConnectAvailabilityProvider
          .overrideWith((ref) async => HealthConnectAvailability.available),
      grantedHealthPermissionsProvider.overrideWith((ref) async => granted),
    ],
    child: const MaterialApp(home: HeartRateScreen()),
  );
}

void main() {
  final today = LocalDate.now();

  testWidgets('Heart rate screen renders hero card + line chart once loaded',
      (tester) async {
    final repo = _FakeHeartRepository(
      summaries: [
        _summary(today, 68),
        _summary(today.minusDays(1), 72),
      ],
    );
    await tester.pumpWidget(
      await _bootstrap(
        heartRepository: repo,
        granted: {HcPermissions.readHeartRate},
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MetricCard), findsWidgets);
    expect(find.byType(MetricLineChart), findsOneWidget);
  });

  testWidgets('Heart rate screen shows the access gate when permission missing',
      (tester) async {
    final repo = _FakeHeartRepository(summaries: [_summary(today, 68)]);
    await tester.pumpWidget(
      await _bootstrap(
        heartRepository: repo,
        granted: const <String>{},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permissions needed'), findsOneWidget);
    expect(find.byType(MetricCard), findsNothing);
  });

  testWidgets('Heart rate screen shows the empty placeholder with no data',
      (tester) async {
    final repo = _FakeHeartRepository();
    await tester.pumpWidget(
      await _bootstrap(
        heartRepository: repo,
        granted: {HcPermissions.readHeartRate},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MetricCardPlaceholder), findsOneWidget);
    expect(find.byType(MetricLineChart), findsNothing);
  });
}
