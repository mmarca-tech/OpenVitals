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
import 'package:openvitals/domain/model/vitals_models.dart';
import 'package:openvitals/domain/query/heart_period_data.dart';
import 'package:openvitals/domain/query/vitals_period_data.dart';
import 'package:openvitals/features/vitals/vitals_screens.dart';
import 'package:openvitals/health/health_permissions.dart';
import 'package:openvitals/ui/components/health_connect_gate.dart';
import 'package:openvitals/ui/components/metric_card.dart';

class _FakeHeartRepository implements HeartRepository {
  @override
  Future<HeartPeriodData> loadHeartPeriod(
    PeriodLoadQuery query,
    HeartPeriodMetric metric, {
    RefreshMode refreshMode = RefreshMode.normal,
  }) async =>
      const HeartPeriodData();

  @override
  Future<List<DailyHrv>> loadDailyHRV(LocalDate start, LocalDate end) async =>
      const <DailyHrv>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVitalsRepository implements VitalsRepository {
  _FakeVitalsRepository({this.bloodPressure = const <BloodPressureEntry>[]});

  final List<BloodPressureEntry> bloodPressure;

  @override
  Set<String> get phase3Permissions => const <String>{};

  @override
  Future<VitalsPeriodData> loadVitalsPeriod(
    PeriodLoadQuery query,
    VitalsPeriodMetric metric, {
    RefreshMode refreshMode = RefreshMode.normal,
  }) async =>
      VitalsPeriodData(bloodPressure: bloodPressure);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BloodPressureEntry _bp(DateTime time, int systolic, int diastolic) =>
    BloodPressureEntry(
      time: time,
      systolicMmHg: systolic,
      diastolicMmHg: diastolic,
      source: 'test',
    );

Future<Widget> _bootstrap({
  required _FakeVitalsRepository vitalsRepository,
  required Set<String> granted,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      heartRepositoryProvider.overrideWithValue(_FakeHeartRepository()),
      vitalsRepositoryProvider.overrideWithValue(vitalsRepository),
      healthConnectAvailabilityProvider
          .overrideWith((ref) async => HealthConnectAvailability.available),
      grantedHealthPermissionsProvider.overrideWith((ref) async => granted),
    ],
    child: const MaterialApp(home: BloodPressureScreen()),
  );
}

void main() {
  final now = DateTime.now().toUtc();

  testWidgets('Blood pressure screen renders the hero card once loaded',
      (tester) async {
    final repo = _FakeVitalsRepository(
      bloodPressure: [
        _bp(now.subtract(const Duration(hours: 2)), 118, 76),
        _bp(now.subtract(const Duration(days: 1)), 122, 80),
      ],
    );
    await tester.pumpWidget(
      await _bootstrap(
        vitalsRepository: repo,
        granted: {HcPermissions.readBloodPressure},
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MetricCard), findsWidgets);
    expect(find.text('Blood pressure'), findsWidgets);
  });

  testWidgets('Blood pressure screen shows the access gate when missing',
      (tester) async {
    final repo = _FakeVitalsRepository(bloodPressure: [_bp(now, 118, 76)]);
    await tester.pumpWidget(
      await _bootstrap(
        vitalsRepository: repo,
        granted: const <String>{},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permissions needed'), findsOneWidget);
    expect(find.byType(MetricCard), findsNothing);
  });

  testWidgets('Blood pressure screen shows placeholder with no readings',
      (tester) async {
    final repo = _FakeVitalsRepository();
    await tester.pumpWidget(
      await _bootstrap(
        vitalsRepository: repo,
        granted: {HcPermissions.readBloodPressure},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MetricCardPlaceholder), findsOneWidget);
  });
}
