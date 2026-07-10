import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/data/repository/contract/apple_health_import_repository.dart';
import 'package:openvitals/di/providers.dart';
import 'package:openvitals/domain/model/health_connect_availability.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_error_formatter.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_models.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_records.dart';
import 'package:openvitals/features/imports/applehealth/apple_health_import_service.dart';
import 'package:openvitals/features/settings/cards/apple_health_import_card.dart';
import 'package:openvitals/l10n/app_localizations.dart';
import 'package:openvitals/ui/components/health_connect_gate.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeRepository implements AppleHealthImportRepository {
  @override
  Future<Set<String>> findMatchingImportedClientRecordIds(
    String recordType,
    DateTime start,
    DateTime end,
    Set<String> wantedIds,
  ) async =>
      const {};

  @override
  Future<void> insertImportedRecords(List<ImportRecord> records) async {}

  @override
  bool isMindfulnessAvailable() => true;
}

final _cannedAnalysis = AppleHealthImportAnalysisResult(
  parsedRecords: 12,
  parsedWorkouts: 0,
  parsedCorrelations: 0,
  parsedActivitySummaries: 0,
  convertedRecords: 12,
  unsupportedElements: 3,
  skippedRecords: 0,
  failedRecords: 0,
  categorySummaries: const [
    AppleHealthImportCategorySummary(
      category: AppleHealthImportCategory.activity,
      convertedRecords: 10,
    ),
    AppleHealthImportCategorySummary(
      category: AppleHealthImportCategory.workouts,
      convertedRecords: 2,
      routeSessions: 1,
    ),
  ],
  typeSummaries: const [],
  diagnostics: const [],
  shareableReportText: 'ANALYSIS_REPORT',
);

const _cannedResult = AppleHealthImportResult(
  parsedRecords: 12,
  parsedWorkouts: 0,
  parsedCorrelations: 0,
  parsedActivitySummaries: 0,
  convertedRecords: 12,
  importedRecords: 9,
  duplicateSkippedRecords: 1,
  notSelectedRecords: 2,
  unsupportedElements: 3,
  skippedRecords: 0,
  failedRecords: 0,
  typeSummaries: [],
  diagnostics: [],
  shareableReportText: 'IMPORT_REPORT',
);

class _FakeService extends AppleHealthImportService {
  _FakeService({this.analysisError}) : super(_FakeRepository());

  final Object? analysisError;

  Set<AppleHealthImportCategory>? importedCategories;
  int analyzeCalls = 0;
  int importCalls = 0;

  @override
  Future<AppleHealthImportAnalysisResult> analyzeAppleHealthExport(
    List<int> bytes, {
    AppleHealthImportProgressCallback? onProgress,
  }) async {
    analyzeCalls++;
    final error = analysisError;
    if (error != null) throw error;
    return _cannedAnalysis;
  }

  @override
  Future<AppleHealthImportResult> importAppleHealthExport(
    List<int> bytes, {
    Set<AppleHealthImportCategory> selectedCategories =
        allAppleHealthImportCategories,
    AppleHealthImportProgressCallback? onProgress,
  }) async {
    importCalls++;
    importedCategories = selectedCategories;
    return _cannedResult;
  }
}

// ── Harness ──────────────────────────────────────────────────────────────────

Future<Widget> _bootstrap(
  _FakeService service, {
  Set<String> granted = const {},
  bool grantAll = false,
  Future<List<int>?> Function()? pickExportBytes,
  Future<bool> Function(String, String)? saveReportFile,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appleHealthImportServiceProvider.overrideWithValue(service),
      healthConnectAvailabilityProvider.overrideWith(
        (ref) async => HealthConnectAvailability.available,
      ),
      grantedHealthPermissionsProvider.overrideWith(
        (ref) async => grantAll
            ? ref.watch(healthRepositoryProvider).dataImportWritePermissions
            : granted,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: AppleHealthImportCard(
            pickExportBytes: pickExportBytes,
            saveReportFile: saveReportFile,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders header, permission line and analyze action',
      (tester) async {
    final service = _FakeService();
    await tester.pumpWidget(await _bootstrap(service));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Apple Health Importer'), findsOneWidget);
    expect(find.textContaining('import permissions granted'), findsOneWidget);
    expect(find.text('Analyze Apple Health export'), findsOneWidget);
  });

  testWidgets('analyze populates the analysis result and category checklist',
      (tester) async {
    final service = _FakeService();
    await tester.pumpWidget(
      await _bootstrap(service, pickExportBytes: () async => const [1, 2, 3]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analyze Apple Health export'));
    await tester.pumpAndSettle();

    expect(service.analyzeCalls, 1);
    expect(find.textContaining('Found 12 compatible records'), findsOneWidget);
    // Per-category checklist with two detected categories.
    expect(find.text('Activity metrics'), findsOneWidget);
    expect(find.text('Workouts and routes'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
    // The route-aware count line for the workouts category.
    expect(find.textContaining('2 records, 1 with routes'), findsOneWidget);
    // After an analysis the action flips to "choose another".
    expect(find.text('Choose another Apple Health export'), findsOneWidget);
    expect(find.text('Import selected categories'), findsOneWidget);
  });

  testWidgets('toggling a category then importing calls import with the '
      'selected set and shows the result', (tester) async {
    final service = _FakeService();
    await tester.pumpWidget(
      await _bootstrap(
        service,
        grantAll: true,
        pickExportBytes: () async => const [1, 2, 3],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analyze Apple Health export'));
    await tester.pumpAndSettle();

    // Both categories auto-selected; deselect workouts (the second checkbox).
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import selected categories'));
    await tester.pumpAndSettle();

    expect(service.importCalls, 1);
    expect(service.importedCategories, {AppleHealthImportCategory.activity});

    // Result summary (six counters) + report actions.
    expect(find.textContaining('Imported 9'), findsOneWidget);
    expect(find.text('Copy report'), findsOneWidget);
    expect(find.text('Download full report'), findsOneWidget);
  });

  testWidgets('save report action invokes the save seam and confirms',
      (tester) async {
    final service = _FakeService();
    String? savedContent;
    await tester.pumpWidget(
      await _bootstrap(
        service,
        grantAll: true,
        pickExportBytes: () async => const [1, 2, 3],
        saveReportFile: (content, name) async {
          savedContent = content;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze Apple Health export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import selected categories'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download full report'));
    await tester.pumpAndSettle();

    expect(savedContent, 'IMPORT_REPORT');
    expect(find.text('Import report saved.'), findsOneWidget);
  });

  testWidgets('analysis failure shows the error text', (tester) async {
    final service = _FakeService(
      analysisError: AppleHealthImportException('boom'),
    );
    await tester.pumpWidget(
      await _bootstrap(service, pickExportBytes: () async => const [1, 2, 3]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analyze Apple Health export'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Import failed'), findsOneWidget);
    expect(find.text('Copy error'), findsOneWidget);
  });
}
