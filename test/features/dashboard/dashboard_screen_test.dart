import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/data/repository/dashboard/dashboard_data_loader.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/model/dashboard_data.dart';
import 'package:openvitals/domain/model/dashboard_query.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/domain/usecase/load_dashboard_day_use_case.dart';
import 'package:openvitals/features/dashboard/dashboard_screen.dart';
import 'package:openvitals/health/health_data_source.dart';
import 'package:openvitals/l10n/app_localizations.dart';
import 'package:openvitals/ui/components/health_connect_gate.dart';
import 'package:openvitals/ui/components/metric_card.dart';
import 'package:openvitals/ui/components/period_navigator.dart';
import 'package:openvitals/ui/components/permission_callout.dart';

/// A [HealthDataSource] whose availability + granted-permission answers are
/// fixed, so the real [HealthRepositoryImpl] over it (and the notifier) resolve
/// deterministically without any platform access.
class _FakeHealthDataSource extends HealthDataSource {
  _FakeHealthDataSource({
    required HealthConnectAvailability availability,
    this.granted = const <String>{},
  }) {
    cachedAvailability = availability;
  }

  Set<String> granted;

  @override
  Future<HealthConnectAvailability> availability() async => cachedAvailability;

  @override
  Future<Set<String>> grantedPermissions() async => granted;
}

/// A [LoadDashboardDayUseCase] whose result is built by [_build] from the query.
class _FakeUseCase extends LoadDashboardDayUseCase {
  _FakeUseCase(this._build) : super(DashboardDataLoader(HealthDataSource()));

  final DashboardData Function(DashboardQuery query) _build;

  @override
  Future<DashboardData> call(DashboardQuery query) async => _build(query);
}

DashboardData _sampleData(DashboardQuery query, {Set<String> missing = const {}}) {
  return DashboardData(
    date: query.date,
    steps: 8000,
    distanceMeters: 5200,
    caloriesKcal: 540,
    hydrationLiters: 1.5,
    avgHeartRateBpm: 72,
    restingHeartRateBpm: 58,
    weightKg: 70,
    caloriesInKcal: 1800,
    proteinGrams: 90,
    loadedMetrics: query.visibleMetrics,
    missingPermissions: missing,
  );
}

Future<Widget> _bootstrap({
  required HealthConnectAvailability availability,
  Set<String> granted = const <String>{},
  Set<String> missing = const <String>{},
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthDataSourceProvider.overrideWithValue(
        _FakeHealthDataSource(availability: availability, granted: granted),
      ),
      healthConnectAvailabilityProvider.overrideWith((ref) async => availability),
      grantedHealthPermissionsProvider.overrideWith((ref) async => granted),
      loadDashboardDayUseCaseProvider.overrideWithValue(
        _FakeUseCase((query) => _sampleData(query, missing: missing)),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: DashboardScreen()),
    ),
  );
}

void main() {
  testWidgets('shows a loader then renders grouped metric cards',
      (tester) async {
    await tester.pumpWidget(
      await _bootstrap(availability: HealthConnectAvailability.available),
    );

    // First frame: the gate/notifier are still resolving asynchronously.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DayNavigator), findsOneWidget);
    expect(find.byType(MetricCard), findsWidgets);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('renders the inline permission callout when permissions missing',
      (tester) async {
    await tester.pumpWidget(
      await _bootstrap(
        availability: HealthConnectAvailability.available,
        missing: {'android.permission.health.READ_STEPS'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PermissionCallout), findsOneWidget);
    // Content still renders below the callout (Kotlin degrades gracefully).
    expect(find.byType(MetricCard), findsWidgets);
  });

  testWidgets('previous-day navigation moves the selected day back',
      (tester) async {
    await tester.pumpWidget(
      await _bootstrap(availability: HealthConnectAvailability.available),
    );
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();

    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('shows the access gate when Health Connect is unavailable',
      (tester) async {
    await tester.pumpWidget(
      await _bootstrap(availability: HealthConnectAvailability.notSupported),
    );
    await tester.pumpAndSettle();

    expect(find.text('Health Connect unavailable'), findsOneWidget);
    expect(find.byType(MetricCard), findsNothing);
  });
}
