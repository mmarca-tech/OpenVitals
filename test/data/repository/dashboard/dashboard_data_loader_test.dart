import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/data/repository/dashboard/dashboard_data_loader.dart';
import 'package:openvitals/domain/model/dashboard_query.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/health/health_data_source.dart';
import 'package:openvitals/health/health_permissions.dart';

/// A device-free [HealthDataSource] that returns canned values for a few metrics
/// and reports a fixed granted-permission set. All other reads fall through to
/// the base class's empty/null defaults.
class _FakeSource extends HealthDataSource {
  _FakeSource(this._granted) {
    cachedAvailability = HealthConnectAvailability.available;
  }

  final Set<String> _granted;

  @override
  Future<Set<String>> grantedPermissions() async => _granted;

  @override
  Future<int> readSteps(LocalDate date) async => 4321;

  @override
  Future<double> readDistanceMeters(LocalDate date) async => 5000.0;

  @override
  Future<double?> readHydrationLiters(LocalDate date) async => 2.5;
}

void main() {
  test('assembles granted metrics and reports missing permissions', () async {
    final source = _FakeSource({
      HcPermissions.readSteps,
      HcPermissions.readDistance,
      // hydration read permission intentionally NOT granted
    });
    final loader = DashboardDataLoader(source);

    final data = await loader.loadDashboard(
      DashboardQuery(
        date: LocalDate(2026, 1, 2),
        visibleMetrics: {
          DashboardMetric.steps,
          DashboardMetric.distance,
          DashboardMetric.hydration,
        },
        includeHistoricalBaselines: false,
        includeWeeklyTrainingSignals: false,
      ),
    );

    expect(data.steps, 4321);
    expect(data.distanceMeters, 5000.0);
    // Not granted → the metric read is skipped and the value stays at 0.
    expect(data.hydrationLiters, 0.0);
    expect(data.missingPermissions, contains(HcPermissions.readHydration));
    expect(data.missingPermissions, isNot(contains(HcPermissions.readSteps)));
    expect(
      data.loadedMetrics,
      {DashboardMetric.steps, DashboardMetric.distance, DashboardMetric.hydration},
    );
  });

  test('returns empty granted set when Health Connect is unavailable', () async {
    final source = _FakeSource({HcPermissions.readSteps})
      ..cachedAvailability = HealthConnectAvailability.notSupported;
    final loader = DashboardDataLoader(source);

    final data = await loader.loadDashboard(
      DashboardQuery(
        date: LocalDate(2026, 1, 2),
        visibleMetrics: {DashboardMetric.steps},
        includeHistoricalBaselines: false,
        includeWeeklyTrainingSignals: false,
      ),
    );

    // Availability gate short-circuits granted permissions, so nothing is read.
    expect(data.steps, 0);
    expect(data.missingPermissions, contains(HcPermissions.readSteps));
  });
}
