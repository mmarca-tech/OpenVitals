import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/core/period/period_load_query.dart';
import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/data/repository/contract/heart_repository.dart';
import 'package:openvitals/data/repository/contract/sleep_repository.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/domain/model/heart_models.dart';
import 'package:openvitals/domain/model/refresh_mode.dart';
import 'package:openvitals/domain/model/sleep_models.dart';
import 'package:openvitals/domain/preferences/sleep_range_mode.dart';
import 'package:openvitals/domain/query/sleep_period_data.dart';
import 'package:openvitals/features/sleep/sleep_screen.dart';
import 'package:openvitals/health/health_permissions.dart';
import 'package:openvitals/ui/charts/period_chart.dart';
import 'package:openvitals/ui/components/health_connect_gate.dart';

/// A fake [SleepRepository] returning canned period data.
class _FakeSleepRepository implements SleepRepository {
  _FakeSleepRepository({this.sessions = const <SleepData>[]});

  final List<SleepData> sessions;

  @override
  Future<SleepPeriodData> loadSleepPeriod(
    PeriodLoadQuery query,
    SleepRangeMode sleepRangeMode, {
    RefreshMode refreshMode = RefreshMode.normal,
  }) async =>
      SleepPeriodData(sessions: sessions);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A fake [HeartRepository]; only the cross-metric HRV load the sleep use case
/// issues is exercised.
class _FakeHeartRepository implements HeartRepository {
  @override
  Future<List<DailyHrv>> loadDailyHRV(LocalDate start, LocalDate end) async =>
      const <DailyHrv>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SleepData _session() {
  final now = DateTime.now();
  final end = DateTime(now.year, now.month, now.day, 7).toUtc();
  final start = end.subtract(const Duration(hours: 8));
  return SleepData(
    id: 's1',
    startTime: start,
    endTime: end,
    durationMs: const Duration(hours: 8).inMilliseconds,
    source: 'test',
    stages: [
      SleepStage(
        startTime: start,
        endTime: start.add(const Duration(hours: 5)),
        stageType: SleepStage.stageLight,
      ),
      SleepStage(
        startTime: start.add(const Duration(hours: 5)),
        endTime: start.add(const Duration(hours: 7)),
        stageType: SleepStage.stageDeep,
      ),
      SleepStage(
        startTime: start.add(const Duration(hours: 7)),
        endTime: end,
        stageType: SleepStage.stageRem,
      ),
    ],
  );
}

Future<Widget> _bootstrap({
  required _FakeSleepRepository sleepRepository,
  required Set<String> granted,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      sleepRepositoryProvider.overrideWithValue(sleepRepository),
      heartRepositoryProvider.overrideWithValue(_FakeHeartRepository()),
      healthConnectAvailabilityProvider
          .overrideWith((ref) async => HealthConnectAvailability.available),
      grantedHealthPermissionsProvider.overrideWith((ref) async => granted),
    ],
    child: const MaterialApp(home: SleepScreen()),
  );
}

void main() {
  testWidgets('Sleep screen renders the overview + duration chart once loaded',
      (tester) async {
    await tester.pumpWidget(
      await _bootstrap(
        sleepRepository: _FakeSleepRepository(sessions: [_session()]),
        granted: {HcPermissions.readSleep},
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MetricBarChart), findsOneWidget);
    expect(find.text('Sleep score'), findsOneWidget);
  });

  testWidgets('Sleep screen shows the access gate when permission missing',
      (tester) async {
    await tester.pumpWidget(
      await _bootstrap(
        sleepRepository: _FakeSleepRepository(sessions: [_session()]),
        granted: const <String>{},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permissions needed'), findsOneWidget);
    expect(find.byType(MetricBarChart), findsNothing);
  });
}
