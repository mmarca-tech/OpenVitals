import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/core/period/period_load_query.dart';
import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/data/repository/contract/body_repository.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/model/body_models.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/domain/model/refresh_mode.dart';
import 'package:openvitals/domain/query/body_period_data.dart';
import 'package:openvitals/features/body/body_metric_screen.dart';
import 'package:openvitals/health/health_permissions.dart';
import 'package:openvitals/ui/components/health_connect_gate.dart';
import 'package:openvitals/ui/components/metric_card.dart';

class _FakeBodyRepository implements BodyRepository {
  _FakeBodyRepository({this.data = const BodyPeriodData()});

  final BodyPeriodData data;

  @override
  Future<BodyPeriodData> loadBodyPeriod(
    PeriodLoadQuery query,
    BodyPeriodMetric metric, {
    RefreshMode refreshMode = RefreshMode.normal,
  }) async =>
      data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WeightEntry _weight(LocalDate date, double kg) => WeightEntry(
      time: DateTime(date.year, date.month, date.day, 8),
      weightKg: kg,
      source: 'test',
    );

Future<Widget> _bootstrap({
  required _FakeBodyRepository repository,
  required Set<String> granted,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      bodyRepositoryProvider.overrideWithValue(repository),
      healthConnectAvailabilityProvider
          .overrideWith((ref) async => HealthConnectAvailability.available),
      grantedHealthPermissionsProvider.overrideWith((ref) async => granted),
    ],
    child: const MaterialApp(home: WeightScreen()),
  );
}

void main() {
  final today = LocalDate.now();

  testWidgets('Weight screen renders the hero card once loaded',
      (tester) async {
    final repo = _FakeBodyRepository(
      data: BodyPeriodData(
        weightEntries: [
          _weight(today, 70.5),
          _weight(today.minusDays(2), 71.2),
        ],
      ),
    );
    await tester.pumpWidget(
      await _bootstrap(repository: repo, granted: {HcPermissions.readWeight}),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MetricCard), findsWidgets);
  });

  testWidgets('Weight screen shows the access gate when permission missing',
      (tester) async {
    final repo = _FakeBodyRepository(
      data: BodyPeriodData(weightEntries: [_weight(today, 70.0)]),
    );
    await tester.pumpWidget(
      await _bootstrap(repository: repo, granted: const <String>{}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permissions needed'), findsOneWidget);
    expect(find.byType(MetricCard), findsNothing);
  });

  testWidgets('Weight screen shows the empty placeholder with no data',
      (tester) async {
    final repo = _FakeBodyRepository();
    await tester.pumpWidget(
      await _bootstrap(repository: repo, granted: {HcPermissions.readWeight}),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MetricCardPlaceholder), findsOneWidget);
  });
}
