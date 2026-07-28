import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/data/repository/impl/health_repository_impl.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/health/health_permissions.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/domain/preferences/app_language.dart';
import 'package:openvitals/features/onboarding/application/onboarding_view_model.dart';
import 'package:openvitals/features/onboarding/presentation/onboarding_screen.dart';
import 'package:openvitals/data/source/health/health_data_source.dart';
import 'package:openvitals/l10n/app_localizations.dart';
import 'package:openvitals/ui/components/app_language_dropdown.dart';
import 'package:openvitals/ui/components/ov_card.dart';

class _FakeHealthDataSource extends HealthDataSource {
  _FakeHealthDataSource({
    required HealthConnectAvailability availability,
    this.granted = const <String>{},
    this.mindfulnessSupportedByDevice = false,
    this.mindfulnessIntegrationEnabled,
  }) {
    cachedAvailability = availability;
  }

  Set<String> granted;

  /// What the provider says about mindfulness, before the user's opt-in.
  final bool mindfulnessSupportedByDevice;

  /// The opt-in itself, read live so flipping the preference changes the answer
  /// the way the real data source's `mindfulnessIntegrationEnabled` callback
  /// does.
  final bool Function()? mindfulnessIntegrationEnabled;

  final List<Set<String>> requested = <Set<String>>[];
  int openedSettingsCount = 0;
  bool get openedSettings => openedSettingsCount > 0;

  @override
  Future<HealthConnectAvailability> availability() async => cachedAvailability;

  @override
  Future<HealthConnectFeatureFlags> resolveFeatureFlags() async {
    final flags = HealthConnectFeatureFlags(
      mindfulnessSupportedByDevice: mindfulnessSupportedByDevice,
      mindfulnessAvailable: mindfulnessSupportedByDevice &&
          (mindfulnessIntegrationEnabled?.call() ?? false),
    );
    featureFlags = flags;
    return flags;
  }

  @override
  Future<Set<String>> grantedPermissions() async => granted;

  @override
  Future<bool> requestPermissions(Set<String> permissions) async {
    requested.add(permissions);
    return true;
  }

  @override
  Future<bool> openHealthConnectSettings() async {
    openedSettingsCount++;
    return true;
  }
}

/// The dashboard-minimum permission set the base permission taxonomy produces.
Set<String> get _requiredPermissions =>
    HealthRepositoryImpl(HealthDataSource()).requiredOnboardingPermissions;

Future<(Widget, SharedPreferences)> _bootstrap({
  required HealthConnectAvailability availability,
  Set<String> granted = const <String>{},
  VoidCallback? onComplete,
  _FakeHealthDataSource? dataSource,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final widget = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthDataSourceProvider.overrideWithValue(
        dataSource ??
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
    expect(find.text('Grant Health Connect access'), findsOneWidget);
  });

  testWidgets('completing onboarding sets the onboarding-done pref',
      (tester) async {
    final (widget, prefs) = await _bootstrap(
      availability: HealthConnectAvailability.available,
      granted: _requiredPermissions,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    // With the minimum granted the primary action is "Continue". The header
    // (language picker + logo) pushes it below the 600px test viewport, so
    // scroll it into view before tapping.
    expect(find.text('Continue'), findsOneWidget);
    expect(prefs.getBool('onboarding_done'), isNot(true));

    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
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
    expect(find.text('Grant Health Connect access'), findsNothing);
  });

  testWidgets('the header renders the wide logo and the language dropdown',
      (tester) async {
    final (widget, _) = await _bootstrap(
      availability: HealthConnectAvailability.available,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The shared AppLanguageDropdown, defaulting to "follow the system" (a
    // closed DropdownButton only builds its selected item).
    expect(find.byType(AppLanguageDropdown), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    // The wide wordmark (decorative: excluded from semantics).
    final logo = tester.widget<Image>(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/icon/openvitals_logo_wide.png',
      ),
    );
    expect(logo.width, 152);
    expect(logo.height, 104);
    expect(logo.excludeFromSemantics, isTrue);
  });

  testWidgets('picking a language persists the app-language preference',
      (tester) async {
    final (widget, prefs) = await _bootstrap(
      availability: HealthConnectAvailability.available,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppLanguageDropdown));
    await tester.pumpAndSettle();
    // The menu overlay adds a second "Deutsch" — tap the one in the menu.
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();

    expect(prefs.getString('app_language'), AppLanguage.german.name);
  });

  testWidgets(
      'a manual-only category shows the manual status and an Open button',
      (tester) async {
    // With the base feature flags, history/background reads are unavailable, so
    // "additional data access" reduces to the manual-only exercise-routes
    // permission: no requestable permission is missing → isManualGrant.
    final dataSource = _FakeHealthDataSource(
      availability: HealthConnectAvailability.available,
    );
    final (widget, _) = await _bootstrap(
      availability: HealthConnectAvailability.available,
      dataSource: dataSource,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Open settings'), findsOneWidget);

    final openButton = find.widgetWithText(FilledButton, 'Open');
    expect(openButton, findsOneWidget);

    await tester.ensureVisible(openButton);
    await tester.pumpAndSettle();
    await tester.tap(openButton);
    await tester.pumpAndSettle();

    // A manual-only category opens Health Connect settings rather than firing
    // the (useless) runtime permission dialog.
    expect(dataSource.openedSettings, isTrue);
    expect(dataSource.requested, isEmpty);
  });

  testWidgets('needsProviderUpdate offers an install action', (tester) async {
    final (widget, _) = await _bootstrap(
      availability: HealthConnectAvailability.needsProviderUpdate,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(
      find.text('Health Connect needs to be installed or updated to use this app.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Install Health Connect'),
      findsOneWidget,
    );
  });

  testWidgets('the other unavailable states offer no install action',
      (tester) async {
    for (final availability in const [
      HealthConnectAvailability.notSupported,
      HealthConnectAvailability.needsPlayStore,
    ]) {
      final (widget, _) = await _bootstrap(availability: availability);
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(
        find.text('Install Health Connect'),
        findsNothing,
        reason: '$availability must not offer an install action',
      );
    }
  });

  testWidgets('the one grant button asks for the whole required set at once',
      (tester) async {
    final dataSource = _FakeHealthDataSource(
      availability: HealthConnectAvailability.available,
    );
    final (widget, _) = await _bootstrap(
      availability: HealthConnectAvailability.available,
      dataSource: dataSource,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    final grant = find.widgetWithText(FilledButton, 'Grant Health Connect access');
    await tester.ensureVisible(grant);
    await tester.pumpAndSettle();
    await tester.tap(grant);
    await tester.pumpAndSettle();

    // ONE request, and it is the required set — not a first instalment of it.
    expect(dataSource.requested, hasLength(1));
    expect(dataSource.requested.single, _requiredPermissions);
    // And there is no second "grant the rest" button to find.
    expect(find.text('Grant remaining available permissions'), findsNothing);
  });

  testWidgets('with the required set outstanding there is no way to continue',
      (tester) async {
    // Everything granted EXCEPT one permission: the hard block means this is
    // still not enough.
    final granted = Set<String>.from(_requiredPermissions)
      ..remove('android.permission.health.READ_SLEEP');
    final (widget, prefs) = await _bootstrap(
      availability: HealthConnectAvailability.available,
      granted: granted,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Grant Health Connect access'),
      findsOneWidget,
    );
    expect(prefs.getBool('onboarding_done'), isNot(true));
  });

  testWidgets('completing onboarding stamps the permission-set version',
      (tester) async {
    final (widget, prefs) = await _bootstrap(
      availability: HealthConnectAvailability.available,
      granted: _requiredPermissions,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Without the stamp, widening the required set later would never reach this
    // user — `onboarding_done` alone is a one-way door.
    expect(
      prefs.getInt('last_prompted_permission_set_version'),
      HealthPermissionService.PERMISSION_SET_VERSION,
    );
  });

  testWidgets('the mindfulness opt-in is hidden when the device lacks it',
      (tester) async {
    final (widget, _) = await _bootstrap(
      availability: HealthConnectAvailability.available,
      dataSource: _FakeHealthDataSource(
        availability: HealthConnectAvailability.available,
      ),
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Include mindfulness'), findsNothing);
    expect(find.text('Mindfulness'), findsNothing);
  });

  testWidgets(
      'the opt-in is offered where the device has it, and only then is '
      'mindfulness asked for', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final dataSource = _FakeHealthDataSource(
      availability: HealthConnectAvailability.available,
      mindfulnessSupportedByDevice: true,
      mindfulnessIntegrationEnabled: () =>
          prefs.getBool('health_connect_mindfulness_enabled') ?? false,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        healthDataSourceProvider.overrideWithValue(dataSource),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Offered, but off — so there is no mindfulness row to grant yet.
    final toggle = find.byType(SwitchListTile);
    expect(toggle, findsOneWidget);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.text('Mindfulness'), findsNothing);

    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(prefs.getBool('health_connect_mindfulness_enabled'), isTrue);
    expect(find.text('Mindfulness'), findsOneWidget);

    // Granting it requests mindfulness ALONE. Folding it into the big batch is
    // what would let a provider that crashes on it cost the user every other
    // permission too.
    dataSource.requested.clear();
    // The Grant inside the mindfulness card specifically — several rows have one.
    final mindfulnessGrant = find.descendant(
      of: find
          .ancestor(
            of: find.text('Mindfulness'),
            matching: find.byType(OpenVitalsCard),
          )
          .first,
      matching: find.widgetWithText(FilledButton, 'Grant'),
    );
    await tester.ensureVisible(mindfulnessGrant);
    await tester.pumpAndSettle();
    await tester.tap(mindfulnessGrant);
    await tester.pumpAndSettle();

    expect(dataSource.requested, hasLength(1));
    expect(
      dataSource.requested.single.every((p) => p.contains('MINDFULNESS')),
      isTrue,
      reason: 'the mindfulness row must request nothing but mindfulness',
    );
  });

  testWidgets('the automatic trip to Health Connect settings happens once',
      (tester) async {
    // Granting the required set leaves exercise routes outstanding, which the
    // runtime dialog cannot grant — so the user is sent to the settings page.
    final dataSource = _FakeHealthDataSource(
      availability: HealthConnectAvailability.available,
    );
    final (widget, _) = await _bootstrap(
      availability: HealthConnectAvailability.available,
      dataSource: dataSource,
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();

    dataSource.granted = _requiredPermissions;
    final grant = find.widgetWithText(FilledButton, 'Grant Health Connect access');
    await tester.ensureVisible(grant);
    await tester.pumpAndSettle();
    await tester.tap(grant);
    await tester.pumpAndSettle();

    expect(dataSource.openedSettingsCount, 1);

    // Coming back from Health Connect re-reads the granted set. Without the
    // latch that re-read would send the user straight back out again, forever.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(dataSource.openedSettingsCount, 1);
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

    final notifier = container.read(onboardingProvider.notifier);
    final categories = notifier.permissionCategories;

    // One-to-one with the Kotlin OnboardingViewModel.permissionCategories order.
    //
    // `mindfulness` is absent because this harness's data source reports the
    // feature unavailable, which since Kotlin 1.9.0 (1f2b435) makes its
    // permission set empty — and onboarding drops empty categories
    // (`.filter { it.permissions.isNotEmpty() }`, OnboardingViewModel.kt:148).
    // That is the point of the fix: never ask for a permission the provider does
    // not define. Settings still lists it, as "Not supported".
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
        'additional_data_access',
        'cycle_tracking',
      ],
    );

    final repo = HealthRepositoryImpl(HealthDataSource());
    OnboardingPermissionCategory byId(String id) =>
        categories.firstWhere((c) => c.id == id);
    expect(byId('manual_entry_write').permissions,
        repo.requestableWritePermissions);
    // Cycle writes are shown with the cycle row, not with the import row, so the
    // import row's count can actually reach "granted" without the opt-in.
    expect(byId('data_import_write').permissions,
        repo.dataImportWritePermissions.difference(repo.cycleWritePermissions));
    expect(byId('cycle_tracking').permissions,
        {...repo.cyclePermissions, ...repo.cycleWritePermissions});
    // Exercise routes ride along additional-data-access but are manual-only.
    expect(byId('additional_data_access').manualPermissions,
        repo.routePermissions);

    // Everything except the opt-in and settings-only rows is required, and the
    // required set is exactly the union of those rows.
    expect(
      categories.where((c) => c.isRequired).map((c) => c.id).toList(),
      const <String>[
        'activity_sleep',
        'heart_recovery',
        'vitals',
        'body',
        'activity_extras',
        'nutrition_hydration',
        'manual_entry_write',
        'data_import_write',
      ],
    );
    expect(
      categories
          .where((c) => c.isRequired)
          .expand((c) => c.permissions)
          .toSet(),
      repo.requiredOnboardingPermissions,
    );
  });

  test('the required set never contains a permission onboarding cannot get',
      () {
    final repo = HealthRepositoryImpl(HealthDataSource());
    final required = repo.requiredOnboardingPermissions;

    // Blocking Continue on a permission the runtime dialog cannot grant is an
    // onboarding nobody can ever leave. Asserted by set intersection rather than
    // by naming strings, so a permission added to any of these groups later is
    // still caught.
    expect(required.intersection(repo.routePermissions), isEmpty);
    expect(required.intersection(repo.additionalDataAccessPermissions), isEmpty);

    // The opt-in groups: asking for these without being asked is the whole
    // thing we promised not to do.
    expect(required.intersection(repo.cyclePermissions), isEmpty);
    expect(required.intersection(repo.cycleWritePermissions), isEmpty);
    expect(required.intersection(repo.mindfulnessPermissions), isEmpty);
    expect(required.intersection(repo.mindfulnessWritePermissions), isEmpty);
    expect(
      required.where((p) => p.contains('MINDFULNESS')),
      isEmpty,
      reason: 'no mindfulness permission may reach the one big request',
    );

    // And it is not empty by accident — the core reads are in there.
    expect(required, containsAll(repo.corePermissions));
    expect(required, containsAll(repo.vitalsPermissions));
  });
}
