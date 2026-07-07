import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/data/repository/contract/body_repository.dart';
import 'package:openvitals/data/repository/contract/hydration_repository.dart';
import 'package:openvitals/data/repository/contract/nutrition_repository.dart';
import 'package:openvitals/data/repository/contract/vitals_repository.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/model/body_models.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/domain/model/nutrition_models.dart';
import 'package:openvitals/domain/model/vitals_models.dart';
import 'package:openvitals/features/manualentry/body_measurement_entry_screen.dart';
import 'package:openvitals/features/manualentry/hydration_entry_screen.dart';
import 'package:openvitals/features/manualentry/vitals_measurement_entry_screen.dart';
import 'package:openvitals/health/health_permissions.dart';
import 'package:openvitals/ui/components/health_connect_gate.dart';

// ── Fake repositories capturing the write requests ────────────────────────────

class _FakeBodyRepository implements BodyRepository {
  BodyMeasurementWriteRequest? written;
  int writeCount = 0;

  @override
  Set<String> bodyWritePermissions(BodyMeasurementType type) =>
      {HcPermissions.writeWeight};

  @override
  Future<bool> hasBodyWritePermission(BodyMeasurementType type) async => true;

  @override
  Future<String> writeBodyMeasurementEntry(
    BodyMeasurementWriteRequest request,
  ) async {
    written = request;
    writeCount += 1;
    return 'record-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVitalsRepository implements VitalsRepository {
  VitalsMeasurementWriteRequest? written;
  int writeCount = 0;

  @override
  Set<String> vitalsWritePermissions(VitalsMeasurementType type) =>
      {HcPermissions.writeBloodPressure};

  @override
  Future<bool> hasVitalsWritePermission(VitalsMeasurementType type) async =>
      true;

  @override
  Future<String> writeVitalsMeasurementEntry(
    VitalsMeasurementWriteRequest request,
  ) async {
    written = request;
    writeCount += 1;
    return 'record-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHydrationRepository implements HydrationRepository {
  HydrationWriteRequest? written;
  int writeCount = 0;

  @override
  Set<String> get hydrationWritePermissions => {HcPermissions.writeHydration};

  @override
  Map<String, double> hydrationContainerVolumeMilliliters() =>
      const <String, double>{};

  @override
  double hydrationDailyGoalLiters() => 2.0;

  @override
  double? lastCustomHydrationAmountMilliliters() => null;

  @override
  void setLastCustomHydrationAmountMilliliters(double milliliters) {}

  @override
  List<CustomHydrationDrink> customHydrationDrinks() =>
      const <CustomHydrationDrink>[];

  @override
  Future<bool> hasHydrationWritePermission() async => true;

  @override
  Future<List<DailyHydration>> loadDailyHydration(
    LocalDate start,
    LocalDate end,
  ) async =>
      const <DailyHydration>[];

  @override
  Future<String> writeHydrationEntry(HydrationWriteRequest request) async {
    written = request;
    writeCount += 1;
    return 'hydration-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNutritionRepository implements NutritionRepository {
  NutritionWriteRequest? written;
  int writeCount = 0;

  @override
  Set<String> get nutritionWritePermissions => {HcPermissions.writeNutrition};

  @override
  Future<bool> hasNutritionWritePermission() async => true;

  @override
  Future<String> writeCarbsEntry(NutritionWriteRequest request) async {
    written = request;
    writeCount += 1;
    return 'carbs-id';
  }

  @override
  Future<String> writeNutritionEntry(NutritionWriteRequest request) async {
    written = request;
    writeCount += 1;
    return 'nutrition-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<SharedPreferences> _prefs() async {
  // Pin the unit system to metric so canonicalisation is deterministic (the
  // default is locale-derived and can resolve to imperial in CI).
  SharedPreferences.setMockInitialValues(
    const <String, Object>{'unit_system': 'metric'},
  );
  return SharedPreferences.getInstance();
}

void main() {
  testWidgets('Body weight form writes the expected request on save',
      (tester) async {
    final repo = _FakeBodyRepository();
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          healthConnectAvailabilityProvider
              .overrideWith((ref) async => HealthConnectAvailability.available),
          grantedHealthPermissionsProvider
              .overrideWith((ref) async => {HcPermissions.writeWeight}),
          bodyRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: BodyMeasurementEntryScreen(bodyMeasurementType: 'WEIGHT'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '72.5');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add Weight'));
    await tester.pumpAndSettle();

    expect(repo.writeCount, 1);
    expect(repo.written!.type, BodyMeasurementType.weight);
    expect(repo.written!.value, 72.5);
  });

  testWidgets('Body weight form blocks the write on invalid input',
      (tester) async {
    final repo = _FakeBodyRepository();
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          healthConnectAvailabilityProvider
              .overrideWith((ref) async => HealthConnectAvailability.available),
          grantedHealthPermissionsProvider
              .overrideWith((ref) async => {HcPermissions.writeWeight}),
          bodyRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: BodyMeasurementEntryScreen(bodyMeasurementType: 'WEIGHT'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No value entered → tapping save records an error, not a write.
    await tester.tap(find.widgetWithText(FilledButton, 'Add Weight'));
    await tester.pumpAndSettle();

    expect(repo.writeCount, 0);
    expect(find.text('Enter a valid Weight value.'), findsOneWidget);
  });

  testWidgets('Blood pressure form writes systolic + diastolic on save',
      (tester) async {
    final repo = _FakeVitalsRepository();
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          healthConnectAvailabilityProvider
              .overrideWith((ref) async => HealthConnectAvailability.available),
          grantedHealthPermissionsProvider
              .overrideWith((ref) async => {HcPermissions.writeBloodPressure}),
          vitalsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: VitalsMeasurementEntryScreen(
            vitalsMeasurementType: 'BLOOD_PRESSURE',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '120');
    await tester.enterText(find.byType(TextField).at(1), '80');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add Blood pressure'));
    await tester.pumpAndSettle();

    expect(repo.writeCount, 1);
    expect(repo.written!.type, VitalsMeasurementType.bloodPressure);
    expect(repo.written!.value, 120.0);
    expect(repo.written!.secondaryValue, 80.0);
  });

  testWidgets('Blood pressure form blocks the write when systolic <= diastolic',
      (tester) async {
    final repo = _FakeVitalsRepository();
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          healthConnectAvailabilityProvider
              .overrideWith((ref) async => HealthConnectAvailability.available),
          grantedHealthPermissionsProvider
              .overrideWith((ref) async => {HcPermissions.writeBloodPressure}),
          vitalsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: VitalsMeasurementEntryScreen(
            vitalsMeasurementType: 'BLOOD_PRESSURE',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '110');
    await tester.enterText(find.byType(TextField).at(1), '120');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add Blood pressure'));
    await tester.pumpAndSettle();

    expect(repo.writeCount, 0);
    expect(find.text('Enter a valid Blood pressure value.'), findsOneWidget);
  });

  testWidgets('Hydration form writes the selected container volume on save',
      (tester) async {
    final hydrationRepo = _FakeHydrationRepository();
    final nutritionRepo = _FakeNutritionRepository();
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          healthConnectAvailabilityProvider
              .overrideWith((ref) async => HealthConnectAvailability.available),
          grantedHealthPermissionsProvider
              .overrideWith((ref) async => {HcPermissions.writeHydration}),
          hydrationRepositoryProvider.overrideWithValue(hydrationRepo),
          nutritionRepositoryProvider.overrideWithValue(nutritionRepo),
        ],
        child: const MaterialApp(home: HydrationEntryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Default selected container is the 100 mL coffee cup (0.1 L).
    final addButton = find.widgetWithText(FilledButton, 'Add 100 mL');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(hydrationRepo.writeCount, 1);
    expect(hydrationRepo.written!.volumeLiters, closeTo(0.1, 1e-9));
  });

  testWidgets('Hydration form blocks the write on an invalid custom amount',
      (tester) async {
    final hydrationRepo = _FakeHydrationRepository();
    final nutritionRepo = _FakeNutritionRepository();
    final prefs = await _prefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          healthConnectAvailabilityProvider
              .overrideWith((ref) async => HealthConnectAvailability.available),
          grantedHealthPermissionsProvider
              .overrideWith((ref) async => {HcPermissions.writeHydration}),
          hydrationRepositoryProvider.overrideWithValue(hydrationRepo),
          nutritionRepositoryProvider.overrideWithValue(nutritionRepo),
        ],
        child: const MaterialApp(home: HydrationEntryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.enterText(field, '0');
    final addButton = find.widgetWithText(FilledButton, 'Add');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(hydrationRepo.writeCount, 0);
    expect(find.text('Enter a valid amount.'), findsOneWidget);
  });
}
