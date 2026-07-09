import 'package:flutter/gestures.dart' show kLongPressTimeout;
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
import 'package:openvitals/ui/components/metric_stat_card.dart';
import 'package:openvitals/ui/components/period_navigator.dart';
import 'package:openvitals/ui/components/permission_callout.dart';
import 'package:openvitals/ui/components/summary_ring_card.dart';

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

/// Enough populated metrics to fill at least three carousel pages (6 tiles per
/// page), so an edge-scroll drag has somewhere to go twice.
DashboardData _threePageData(DashboardQuery query) {
  return _sampleData(query).copyWith(
    activeCaloriesKcal: 320,
    floorsClimbed: 12,
    elevationGainedMeters: 140,
    carbsGrams: 210,
    fatGrams: 60,
    latestSystolicMmHg: 118,
    latestDiastolicMmHg: 76,
    latestSpO2Percent: 97,
    latestVo2Max: 44,
    avgRespiratoryRate: 14,
    latestBodyTemperatureCelsius: 36.7,
    hrvRmssdMs: 42,
    hrvSampleCount: 30,
  );
}

Future<Widget> _bootstrap({
  required HealthConnectAvailability availability,
  Set<String> granted = const <String>{},
  Set<String> missing = const <String>{},
  DashboardData Function(DashboardQuery query)? dataBuilder,
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
        _FakeUseCase(
          dataBuilder ?? (query) => _sampleData(query, missing: missing),
        ),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: DashboardScreen()),
    ),
  );
}

/// Drives the layout on a tall test surface. The square hero ring cards are half
/// the screen wide, so on the default 800×600 surface they inflate to ~380dp
/// tall and push the lazily-built stat-tile carousel outside the render cache; a
/// taller viewport keeps the whole summary column on screen (and the width stays
/// wide enough for the permission callout not to overflow).
void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('shows a loader then renders the summary dashboard',
      (tester) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      await _bootstrap(availability: HealthConnectAvailability.available),
    );

    // First frame: the gate/notifier are still resolving asynchronously.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DayNavigator), findsOneWidget);
    // Two hero ring cards (Steps + Weekly cardio) and a carousel of stat tiles.
    expect(find.byType(SummaryRingCard), findsNWidgets(2));
    expect(find.byType(MetricStatCard), findsWidgets);
    // The Log / Start quick-action row.
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('edge-scroll keeps paging while a drag is held at the edge',
      (tester) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      await _bootstrap(
        availability: HealthConnectAvailability.available,
        dataBuilder: _threePageData,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit dashboard'));
    await tester.pumpAndSettle();

    final pager = find.byType(PageView);
    int currentPage() =>
        tester.widget<PageView>(pager).controller!.page!.round();
    expect(currentPage(), 0);

    // Three pages of tiles, so the drag has somewhere to go twice.
    expect(tester.widget<PageView>(pager).childrenDelegate.estimatedChildCount,
        greaterThanOrEqualTo(3));

    // Long-press a carousel tile (not a hero ring), then drag it into the
    // right-hand edge zone.
    final gesture = await tester.startGesture(
      tester.getCenter(
        find
            .descendant(
              of: pager,
              matching: find.byType(LongPressDraggable<int>),
            )
            .first,
      ),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    final rect = tester.getRect(pager);
    await gesture.moveTo(Offset(rect.right - 8, rect.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(currentPage(), 1);

    // Hold still at the edge. `onDragUpdate` no longer fires, so only the
    // repeating timer can advance the pager — this is the regression: paging
    // used to stall here after the first page.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(currentPage(), 2);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit mode enters/exits and reorder+hide render without error',
      (tester) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      await _bootstrap(availability: HealthConnectAvailability.available),
    );
    await tester.pumpAndSettle();

    // Enter edit mode.
    await tester.tap(find.byTooltip('Edit dashboard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Eye toggles appear on both rings + tiles.
    expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
    // Edit mode reorders in the carousel itself (not a separate flat grid): the
    // paged carousel is present and its tiles are long-press draggable.
    expect(
      find.text('Hold to drag & reorder · tap the eye to hide'),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(LongPressDraggable<int>), findsWidgets);

    // Hide a tile via its eye toggle.
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Exit edit mode; the carousel must render again.
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MetricStatCard), findsWidgets);
  });

  testWidgets('renders the inline permission callout when permissions missing',
      (tester) async {
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      await _bootstrap(
        availability: HealthConnectAvailability.available,
        missing: {'android.permission.health.READ_STEPS'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PermissionCallout), findsOneWidget);
    // Content still renders below the callout (Kotlin degrades gracefully).
    expect(find.byType(SummaryRingCard), findsNWidgets(2));
    expect(find.byType(MetricStatCard), findsWidgets);
  });

  testWidgets('previous-day navigation moves the selected day back',
      (tester) async {
    _usePhoneViewport(tester);
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
    _usePhoneViewport(tester);
    await tester.pumpWidget(
      await _bootstrap(availability: HealthConnectAvailability.notSupported),
    );
    await tester.pumpAndSettle();

    expect(find.text('Health Connect unavailable'), findsOneWidget);
    expect(find.byType(SummaryRingCard), findsNothing);
    expect(find.byType(MetricStatCard), findsNothing);
  });
}
