import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/data/repository/impl/health_repository_impl.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/features/onboarding/onboarding_notifier.dart';
import 'package:openvitals/features/onboarding/onboarding_screen.dart';
import 'package:openvitals/health/health_data_source.dart';
import 'package:openvitals/l10n/app_localizations.dart';

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

/// The dashboard-minimum permission set the base permission taxonomy produces.
Set<String> get _minimumPermissions =>
    HealthRepositoryImpl(HealthDataSource()).minimumOnboardingPermissions;

Future<(Widget, SharedPreferences)> _bootstrap({
  required HealthConnectAvailability availability,
  Set<String> granted = const <String>{},
  VoidCallback? onComplete,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final widget = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthDataSourceProvider.overrideWithValue(
        _FakeHealthDataSource(availability: availability, granted: granted),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OnboardingScreen(onOnboardingComplete: onComplete),
    ),
  );
  return (widget, prefs);
}

void main() {
  testWidgets('shows a loader then the grant-all flow when nothing granted',
      (tester) async {
    final (widget, _) = await _bootstrap(
      availability: HealthConnectAvailability.available,
    );
    await tester.pumpWidget(widget);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('OpenVitals'), findsOneWidget);
    expect(find.text('Grant required Health Connect permissions'), findsOneWidget);
  });

  testWidgets('completing onboarding sets the onboarding-done pref',
      (tester) async {
    final (widget, prefs) = await _bootstrap(
      availability: HealthConnectAvailability.available,
      granted: _minimumPermissions,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // With the minimum granted the primary action is "Continue".
    expect(find.text('Continue'), findsOneWidget);
    expect(prefs.getBool('onboarding_done'), isNot(true));

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(prefs.getBool('onboarding_done'), isTrue);
  });

  testWidgets('shows the unavailable message when Health Connect is missing',
      (tester) async {
    final (widget, _) = await _bootstrap(
      availability: HealthConnectAvailability.notSupported,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(
      find.text('Health Connect is not supported on this device.'),
      findsOneWidget,
    );
    expect(find.text('Grant required Health Connect permissions'), findsNothing);
  });

  test('permissionCategories match the Kotlin source groups and order', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        healthDataSourceProvider.overrideWithValue(
          _FakeHealthDataSource(
            availability: HealthConnectAvailability.available,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(onboardingNotifierProvider.notifier);
    final categories = notifier.permissionCategories;

    // One-to-one with the Kotlin OnboardingViewModel.permissionCategories order.
    expect(
      categories.map((c) => c.id).toList(),
      const <String>[
        'activity_sleep',
        'heart_recovery',
        'vitals',
        'body',
        'activity_extras',
        'nutrition_hydration',
        'manual_entry_write',
        'data_import_write',
        'mindfulness',
        'additional_data_access',
        'cycle_tracking',
      ],
    );

    final repo = HealthRepositoryImpl(HealthDataSource());
    OnboardingPermissionCategory byId(String id) =>
        categories.firstWhere((c) => c.id == id);
    expect(byId('manual_entry_write').permissions,
        repo.requestableWritePermissions);
    expect(
        byId('data_import_write').permissions, repo.dataImportWritePermissions);
    // Exercise routes ride along additional-data-access but are manual-only.
    expect(byId('additional_data_access').manualPermissions,
        repo.routePermissions);
  });
}
