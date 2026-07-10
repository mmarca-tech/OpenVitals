/// Riverpod notifier driving the Settings "Apple Health import" card, ported
/// from the Kotlin `SettingsViewModel` Apple Health import wiring.
///
/// The Kotlin side runs the import through a WorkManager worker that survives
/// the UI; this Dart port deliberately runs the already-DI-wired
/// [AppleHealthImportService] async in the foreground (see the service's own
/// class comment) and mirrors the same observable state: analyze (scan +
/// summarise by category without writing), toggle categories, then import the
/// selected set, persisting the shareable report through the
/// [AppleHealthImportReportStore].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import 'apple_health_import_error_formatter.dart';
import 'apple_health_import_models.dart';
import 'apple_health_import_report_store.dart';
import 'apple_health_import_service.dart';

/// Immutable UI state mirroring the Apple Health fields of the Kotlin
/// `SettingsUiState` consumed by `AppleHealthImportCard`.
class AppleHealthImportUiState {
  const AppleHealthImportUiState({
    this.isAnalyzing = false,
    this.isImporting = false,
    this.analysisProgress,
    this.analysis,
    this.selectedCategories = const <AppleHealthImportCategory>{},
    this.progress,
    this.result,
    this.error,
    this.permissionDenied = false,
  });

  final bool isAnalyzing;
  final bool isImporting;
  final AppleHealthImportProgress? analysisProgress;
  final AppleHealthImportAnalysisResult? analysis;
  final Set<AppleHealthImportCategory> selectedCategories;
  final AppleHealthImportProgress? progress;
  final AppleHealthImportResult? result;
  final String? error;
  final bool permissionDenied;

  bool get isBusy => isAnalyzing || isImporting;

  /// Copy that only ever *sets* the incremental fields; state transitions that
  /// clear a nullable field construct a fresh [AppleHealthImportUiState].
  AppleHealthImportUiState copyWith({
    bool? isAnalyzing,
    bool? isImporting,
    AppleHealthImportProgress? analysisProgress,
    AppleHealthImportProgress? progress,
    AppleHealthImportAnalysisResult? analysis,
    Set<AppleHealthImportCategory>? selectedCategories,
    AppleHealthImportResult? result,
    String? error,
    bool? permissionDenied,
  }) =>
      AppleHealthImportUiState(
        isAnalyzing: isAnalyzing ?? this.isAnalyzing,
        isImporting: isImporting ?? this.isImporting,
        analysisProgress: analysisProgress ?? this.analysisProgress,
        analysis: analysis ?? this.analysis,
        selectedCategories: selectedCategories ?? this.selectedCategories,
        progress: progress ?? this.progress,
        result: result ?? this.result,
        error: error ?? this.error,
        permissionDenied: permissionDenied ?? this.permissionDenied,
      );
}

class AppleHealthImportNotifier extends Notifier<AppleHealthImportUiState> {
  AppleHealthImportService get _service =>
      ref.read(appleHealthImportServiceProvider);
  AppleHealthImportReportStore get _reportStore =>
      ref.read(appleHealthImportReportStoreProvider);

  /// The bytes of the most recently analyzed export, reused by [importSelected]
  /// (the Kotlin `pendingAppleHealthImportUri`).
  List<int>? _pendingBytes;
  String _lastReportText = '';
  String _lastFailureText = '';

  @override
  AppleHealthImportUiState build() {
    // Read the last persisted report/failure back on card open so the Save
    // report action has content even before a fresh import runs this session.
    _lastReportText = _reportStore.readReport();
    _lastFailureText = _reportStore.readFailure();
    return const AppleHealthImportUiState();
  }

  /// The best available report text for the Save action, favouring the live
  /// result, then a live error, then the last persisted report/failure.
  String get reportTextForSave {
    final result = state.result;
    if (result != null) return result.shareableReportText;
    final error = state.error;
    if (error != null && error.isNotEmpty) return error;
    if (_lastReportText.isNotEmpty) return _lastReportText;
    return _lastFailureText;
  }

  /// Scan + summarise an export by category without writing anything, then
  /// auto-select the detected categories (Kotlin `runFullAppleHealthAnalysis`).
  Future<void> analyze(List<int> bytes) async {
    if (state.isBusy) return;
    _pendingBytes = bytes;
    state = const AppleHealthImportUiState(
      isAnalyzing: true,
      analysisProgress:
          AppleHealthImportProgress(phase: AppleHealthImportPhase.queued),
    );
    try {
      final analysis = await _service.analyzeAppleHealthExport(
        bytes,
        onProgress: (progress) {
          if (ref.mounted && state.isAnalyzing) {
            state = state.copyWith(analysisProgress: progress);
          }
        },
      );
      final detected = analysis.categorySummaries
          .map((summary) => summary.category)
          .toSet();
      state = AppleHealthImportUiState(
        analysis: analysis,
        selectedCategories: detected,
      );
    } catch (error) {
      _pendingBytes = null;
      state = AppleHealthImportUiState(
        error: AppleHealthImportErrorFormatter.details(error),
        permissionDenied:
            AppleHealthImportErrorFormatter.isPermissionDenied(error),
      );
    }
  }

  void setCategorySelected(AppleHealthImportCategory category, bool selected) {
    final current = state.selectedCategories;
    final next = <AppleHealthImportCategory>{...current};
    if (selected) {
      next.add(category);
    } else {
      next.remove(category);
    }
    state = state.copyWith(selectedCategories: next);
  }

  /// Convert + dedup + write the selected categories, then persist the report
  /// (Kotlin `importSelectedAppleHealthExport`).
  Future<void> importSelected() async {
    if (state.isBusy) return;
    final bytes = _pendingBytes;
    final analysis = state.analysis;
    if (bytes == null || analysis == null) return;
    final selected = state.selectedCategories;
    if (selected.isEmpty) return;

    final expectedSelectedRecords = analysis.categorySummaries
        .where((summary) => selected.contains(summary.category))
        .fold<int>(0, (sum, summary) => sum + summary.convertedRecords);

    state = state.copyWith(
      isImporting: true,
      progress: AppleHealthImportProgress(
        phase: AppleHealthImportPhase.queued,
        expectedSelectedRecords: expectedSelectedRecords,
      ),
    );
    try {
      final result = await _service.importAppleHealthExport(
        bytes,
        selectedCategories: selected,
        onProgress: (progress) {
          if (ref.mounted && state.isImporting) {
            // The service emits progress without the expected total, so re-seed
            // it here to keep the percent getter meaningful (Kotlin seeds it in
            // the QUEUED progress the worker inherits).
            state = state.copyWith(
              progress: progress.copyWith(
                expectedSelectedRecords: expectedSelectedRecords,
              ),
            );
          }
        },
      );
      await _reportStore.writeReport(result.shareableReportText);
      _lastReportText = result.shareableReportText;
      state = AppleHealthImportUiState(
        analysis: analysis,
        selectedCategories: selected,
        result: result,
      );
    } catch (error) {
      final failureText = buildAppleHealthFailureReportText(error);
      await _reportStore.writeFailure(failureText);
      _lastFailureText = failureText;
      state = AppleHealthImportUiState(
        analysis: analysis,
        selectedCategories: selected,
        error: AppleHealthImportErrorFormatter.details(error),
        permissionDenied:
            AppleHealthImportErrorFormatter.isPermissionDenied(error),
      );
    }
  }
}

final appleHealthImportNotifierProvider =
    NotifierProvider<AppleHealthImportNotifier, AppleHealthImportUiState>(
  AppleHealthImportNotifier.new,
);
