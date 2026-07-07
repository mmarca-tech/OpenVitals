import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/core/period/period_load_query.dart';
import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/data/repository/contract/activity_repository.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/model/activity_models.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/domain/model/refresh_mode.dart';
import 'package:openvitals/domain/query/activity_period_data.dart';
import 'package:openvitals/features/activity/activities_screen.dart';
import 'package:openvitals/features/activity/activity_metric.dart';
import 'package:openvitals/features/activity/activity_metric_screen.dart';
import 'package:openvitals/health/health_permissions.dart';
import 'package:openvitals/ui/charts/period_chart.dart';
import 'package:openvitals/ui/components/health_connect_gate.dart';
import 'package:openvitals/ui/components/metric_card.dart';

/// A fake [ActivityRepository] returning canned period data. Only the handful of
/// methods the activity screens call are overridden; everything else routes
/// through [noSuchMethod] (and throws if unexpectedly reached).
class _FakeActivityRepository implements ActivityRepository {
  _FakeActivityRepository({
    this.dailySteps = const <DailySteps>[],
    this.workouts = const <ExerciseData>[],
  });

  final List<DailySteps> dailySteps;
  final List<ExerciseData> workouts;

  @override
  Future<ActivityPeriodData> loadActivityPeriod(
    PeriodLoadQuery query, {
    required bool includeSteps,
    required bool includeNutrition,
    bool includeWheelchairPushes = false,
    RefreshMode refreshMode = RefreshMode.normal,
  }) async =>
      ActivityPeriodData(dailySteps: dailySteps);

  @override
  Future<List<ExerciseData>> loadWorkouts(LocalDate start, LocalDate end) async =>
      workouts;

  @override
  Future<List<PlannedExerciseData>> loadPlannedWorkouts(
    LocalDate start,
    LocalDate end,
  ) async =>
      const <PlannedExerciseData>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DailySteps _steps(LocalDate date, int steps) => DailySteps(
      date: date,
      steps: steps,
      distanceMeters: steps.toDouble() * 0.7,
      activeCaloriesKcal: steps.toDouble() * 0.04,
      floorsClimbed: 3,
      elevationGainedMeters: 12,
    );

ExerciseData _workout() {
  final start = DateTime.now().toUtc().subtract(const Duration(hours: 2));
  return ExerciseData(
    id: 'w1',
    title: 'Morning run',
    exerciseType: 0,
    startTime: start,
    endTime: start.add(const Duration(minutes: 40)),
    durationMs: const Duration(minutes: 40).inMilliseconds,
    source: 'test',
    totalDistanceMeters: 6000,
  );
}

Future<Widget> _bootstrap({
  required Widget screen,
  required _FakeActivityRepository repository,
  required Set<String> granted,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      activityRepositoryProvider.overrideWithValue(repository),
      healthConnectAvailabilityProvider
          .overrideWith((ref) async => HealthConnectAvailability.available),
      grantedHealthPermissionsProvider.overrideWith((ref) async => granted),
    ],
    child: MaterialApp(home: screen),
  );
}

void main() {
  final today = LocalDate.now();

  testWidgets('Steps screen renders hero card + chart once loaded',
      (tester) async {
    final repo = _FakeActivityRepository(
      dailySteps: [
        _steps(today, 9000),
        _steps(today.minusDays(1), 7000),
      ],
    );
    await tester.pumpWidget(
      await _bootstrap(
        screen: const StepsScreen(),
        repository: repo,
        granted: {HcPermissions.readSteps},
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(MetricCard), findsWidgets);
    expect(find.byType(MetricBarChart), findsOneWidget);
  });

  testWidgets('Steps screen shows the access gate when permission missing',
      (tester) async {
    final repo = _FakeActivityRepository(dailySteps: [_steps(today, 9000)]);
    await tester.pumpWidget(
      await _bootstrap(
        screen: const StepsScreen(),
        repository: repo,
        granted: const <String>{},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Permissions needed'), findsOneWidget);
    expect(find.byType(MetricCard), findsNothing);
  });

  testWidgets('Steps screen shows the empty placeholder with no data',
      (tester) async {
    final repo = _FakeActivityRepository(dailySteps: const <DailySteps>[]);
    await tester.pumpWidget(
      await _bootstrap(
        screen: const ActivityMetricScreen(metric: ActivityMetric.steps),
        repository: repo,
        granted: {HcPermissions.readSteps},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MetricCardPlaceholder), findsOneWidget);
    expect(find.byType(MetricBarChart), findsNothing);
  });

  testWidgets('Activities screen renders the workout list', (tester) async {
    final repo = _FakeActivityRepository(workouts: [_workout()]);
    await tester.pumpWidget(
      await _bootstrap(
        screen: const ActivitiesScreen(),
        repository: repo,
        granted: {HcPermissions.readExercise},
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Morning run'), findsOneWidget);
    expect(find.text('Workouts'), findsOneWidget);
  });

  testWidgets('Activities screen shows placeholder when there are no workouts',
      (tester) async {
    final repo = _FakeActivityRepository();
    await tester.pumpWidget(
      await _bootstrap(
        screen: const ActivitiesScreen(),
        repository: repo,
        granted: {HcPermissions.readExercise},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MetricCardPlaceholder), findsOneWidget);
  });
}
