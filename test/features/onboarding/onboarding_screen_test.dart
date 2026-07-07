import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/data/repository/impl/health_repository_impl.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
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
}
