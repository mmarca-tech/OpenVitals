import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/core/presentation/metric_detail_sections.dart';
import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/data/repository/contract/activity_repository.dart';
import 'package:openvitals/data/repository/contract/heart_repository.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/model/activity_models.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/domain/model/heart_models.dart';
import 'package:openvitals/domain/model/nutrition_models.dart';
import 'package:openvitals/domain/preferences/metric_detail_section_id.dart';
import 'package:openvitals/features/activity/activities_screen.dart';
import 'package:openvitals/health/health_permissions.dart';
import 'package:openvitals/l10n/app_localizations.dart';
import 'package:openvitals/ui/charts/period_chart.dart';
import 'package:openvitals/ui/charts/sparkline_chart.dart';
import 'package:openvitals/ui/components/health_connect_gate.dart';
import 'package:openvitals/ui/components/daily_goal_components.dart';
import 'package:openvitals/ui/components/data_confidence_card.dart';

/// A fake [ActivityRepository]; only the methods the aggregate screen calls are
/// overridden. Everything else routes through [noSuchMethod].
class _FakeActivityRepository implements ActivityRepository {
  _FakeActivityRepository({
    this.workouts = const <ExerciseData>[],
    this.dailySteps = const <DailySteps>[],
    this.nutrition = const <DailyNutrition>[],
  });

  final List<ExerciseData> workouts;
  final List<PlannedExerciseData> planned = const <PlannedExerciseData>[];
  final List<DailySteps> dailySteps;
  final List<DailyNutrition> nutrition;

  final List<String> deleted = <String>[];

  @override
  Future<List<ExerciseData>> loadWorkouts(LocalDate start, LocalDate end) async =>
      workouts;

  @override
  Future<List<PlannedExerciseData>> loadPlannedWorkouts(
    LocalDate start,
    LocalDate end,
  ) async =>
      planned;

  @override
  Future<List<DailySteps>> loadDailySteps(LocalDate start, LocalDate end) async =>
      dailySteps;

  @override
  Future<List<DailyNutrition>> loadDailyNutrition(
    LocalDate start,
    LocalDate end,
  ) async =>
      nutrition;

  @override
  Future<void> deleteActivityEntry(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeartRepository implements HeartRepository {
  @override
  Future<List<HeartRateSample>> loadHeartRateSamples(
    LocalDate start,
    LocalDate end,
  ) async =>
      const <HeartRateSample>[];

  @override
  Future<List<DailyRestingHR>> loadDailyRestingHR(
    LocalDate start,
    LocalDate end,
  ) async =>
      const <DailyRestingHR>[];

  @override
  Future<List<DailyHrv>> loadDailyHRV(LocalDate start, LocalDate end) async =>
      const <DailyHrv>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DailySteps _steps(LocalDate date, int steps) => DailySteps(
      date: date,
      steps: steps,
      distanceMeters: steps.toDouble() * 0.7,
      activeCaloriesKcal: steps.toDouble() * 0.04,
    );

DailyNutrition _nutrition(LocalDate date) => DailyNutrition(
      date: date,
      hydrationLiters: 0,
      caloriesBurnedKcal: 2200,
    );

ExerciseData _workout({
  required String id,
  required String title,
  required int type,
  Duration duration = const Duration(minutes: 40),
  bool openVitals = false,
}) {
  final start = DateTime.now().toUtc().subtract(const Duration(hours: 2));
  return ExerciseData(
    id: id,
    title: title,
    exerciseType: type,
    startTime: start,
    endTime: start.add(duration),
    durationMs: duration.inMilliseconds,
    source: 'test',
    totalDistanceMeters: 6000,
    isOpenVitalsEntry: openVitals,
  );
}

Future<Widget> _bootstrap({
  required _FakeActivityRepository repository,
  HeartRepository? heartRepository,
  SharedPreferences? prefs,
}) async {
  final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/activity',
    routes: [
      GoRoute(path: '/activity', builder: (c, s) => const ActivitiesScreen()),
      GoRoute(
        path: '/metric/:id',
        builder: (c, s) => Text('metric:${s.pathParameters['id']}'),
      ),
      GoRoute(path: '/calories', builder: (c, s) => const Text('route:calories')),
      GoRoute(
        path: '/activity/cardio_load',
        builder: (c, s) => const Text('route:cardio'),
      ),
      GoRoute(
        path: '/activity_detail/:id',
        builder: (c, s) => const Text('route:detail'),
      ),
      GoRoute(
        path: '/manual_entry/activity',
        builder: (c, s) =>
            Text('route:plan:${s.uri.queryParameters['planId'] ?? ''}'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      activityRepositoryProvider.overrideWithValue(repository),
      heartRepositoryProvider
          .overrideWithValue(heartRepository ?? _FakeHeartRepository()),
      healthConnectAvailabilityProvider
          .overrideWith((ref) async => HealthConnectAvailability.available),
      grantedHealthPermissionsProvider
          .overrideWith((ref) async => {HcPermissions.readExercise}),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final today = LocalDate.now();

  setUp(() => SharedPreferences.setMockInitialValues(const <String, Object>{}));

  testWidgets('renders the Kotlin activities sections from a period',
      (tester) async {
    _tallScreen(tester);
    final repo = _FakeActivityRepository(
      workouts: [_workout(id: 'w1', title: 'Morning run', type: 56)],
      dailySteps: [_steps(today, 9000), _steps(today.minusDays(1), 7000)],
      nutrition: [_nutrition(today), _nutrition(today.minusDays(1))],
    );
    await tester.pumpWidget(await _bootstrap(repository: repo));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // ACTIVITY_SUMMARY: the period workout row.
    expect(find.text('Morning run'), findsOneWidget);
    // ACTIVITY_KEY_METRICS: the five metric cards with sparklines.
    expect(find.text('Key metrics'), findsOneWidget);
    expect(find.byType(SparklineChart), findsNWidgets(5));
    // PERIOD_CHART, DAILY_GOAL, STATISTICS, DATA_CONFIDENCE.
    expect(find.byType(MetricBarChart), findsOneWidget);
    expect(find.byType(DailyGoalCard), findsOneWidget);
    expect(find.byType(DailyGoalStatistics), findsOneWidget);
    expect(find.byType(DataConfidenceCard), findsOneWidget);
  });

  testWidgets('the activity-type filter narrows the workout list',
      (tester) async {
    _tallScreen(tester);
    final repo = _FakeActivityRepository(
      workouts: [
        _workout(id: 'w1', title: 'Morning run', type: 56),
        _workout(id: 'w2', title: 'Evening ride', type: 8),
      ],
      dailySteps: [_steps(today, 9000)],
    );
    await tester.pumpWidget(await _bootstrap(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Morning run'), findsOneWidget);
    expect(find.text('Evening ride'), findsOneWidget);

    // Open the "Activity type" dropdown and pick Cycling.
    await tester.tap(find.byWidgetPredicate(
      (w) => w is DropdownButtonFormField<int?>,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cycling').last);
    await tester.pumpAndSettle();

    expect(find.text('Morning run'), findsNothing);
    expect(find.text('Evening ride'), findsOneWidget);
  });

  testWidgets('key-metric cards navigate to their metric targets',
      (tester) async {
    _tallScreen(tester);
    final repo = _FakeActivityRepository(
      workouts: [_workout(id: 'w1', title: 'Morning run', type: 56)],
      dailySteps: [_steps(today, 9000), _steps(today.minusDays(1), 7000)],
      nutrition: [_nutrition(today)],
    );
    await tester.pumpWidget(await _bootstrap(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();
    expect(find.text('metric:STEPS'), findsOneWidget);
  });

  testWidgets('the cardio-load card opens the cardio-load detail',
      (tester) async {
    _tallScreen(tester);
    final repo = _FakeActivityRepository(
      workouts: [_workout(id: 'w1', title: 'Morning run', type: 56)],
      dailySteps: [_steps(today, 9000), _steps(today.minusDays(1), 7000)],
    );
    await tester.pumpWidget(await _bootstrap(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cardio load'));
    await tester.pumpAndSettle();
    expect(find.text('route:cardio'), findsOneWidget);
  });

  testWidgets('the goal steppers move and persist the workout goal',
      (tester) async {
    _tallScreen(tester);
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeActivityRepository(
      workouts: [_workout(id: 'w1', title: 'Morning run', type: 56)],
      dailySteps: [_steps(today, 9000)],
    );
    await tester.pumpWidget(await _bootstrap(repository: repo, prefs: prefs));
    await tester.pumpAndSettle();

    // The workout goal defaults to 30 minutes and steps by 5.
    expect(find.text('30'), findsWidgets);
    await tester.tap(find.byTooltip('Increase daily goal'));
    await tester.pumpAndSettle();
    expect(find.text('35'), findsWidgets);

    // Remount with the same preferences: the stepped goal survives.
    await tester.pumpWidget(await _bootstrap(repository: repo, prefs: prefs));
    await tester.pumpAndSettle();
    expect(find.text('35'), findsWidgets);
  });

  test('the section order persists across notifier instances', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final first = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final before = first.read(metricDetailSectionOrderProvider);
    final MetricDetailSectionId moved = before.first;
    first
        .read(metricDetailSectionOrderProvider.notifier)
        .moveSection(moved, 1);
    final after = first.read(metricDetailSectionOrderProvider);
    first.dispose();
    expect(after, isNot(before));

    final second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    expect(second.read(metricDetailSectionOrderProvider), after);
    second.dispose();
  });
}
