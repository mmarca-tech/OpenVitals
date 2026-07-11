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
///
/// Because Kotlin's WorkManager worker has no Flutter counterpart, the
/// staging/checkpoint orchestration it owns lives here instead:
///
///   load checkpoint → stage the export → import → on success clear both.
///
/// The picked export is never read into memory: it is staged to app-private
/// storage (with a verified byte count) and everything downstream works against
/// that [File]. Resume degrades gracefully — a foreground import that is killed
/// resumes when the user relaunches and re-picks the same export, skipping the
/// batches that were already committed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import 'apple_health_import_checkpoint_store.dart';
import 'apple_health_import_error_formatter.dart';
import 'apple_health_import_models.dart';
import 'apple_health_import_report_store.dart';
import 'apple_health_import_service.dart';
import 'apple_health_import_staging_store.dart';

final appleHealthImportStagingStoreProvider =
    Provider<AppleHealthImportStagingStore>(
  (ref) => AppleHealthImportStagingStore(),
);

final appleHealthImportCheckpointStoreProvider =
    Provider<AppleHealthImportCheckpointStore>(
  (ref) => AppleHealthImportCheckpointStore(),
);

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
  AppleHealthImportStagingStore get _stagingStore =>
      ref.read(appleHealthImportStagingStoreProvider);
  AppleHealthImportCheckpointStore get _checkpointStore =>
      ref.read(appleHealthImportCheckpointStoreProvider);

  /// The most recently analyzed export, reused by [importSelected] (the Kotlin
  /// `pendingAppleHealthImportUri`). Only the *identity* of the pick is held —
  /// its bytes live in the staged file.
  AppleHealthExportSource? _pendingSource;
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

  /// Stage the picked export into app-private storage (verifying the copied
  /// byte count), then scan + summarise it by category without writing anything,
  /// and auto-select the detected categories (Kotlin
  /// `analyzeStagedAppleHealthExport`).
  Future<void> analyze(AppleHealthExportSource source) async {
    if (state.isBusy) return;
    _pendingSource = source;
    state = const AppleHealthImportUiState(
      isAnalyzing: true,
      analysisProgress:
          AppleHealthImportProgress(phase: AppleHealthImportPhase.queued),
    );
    try {
      final staged = await _stagingStore.stage(source);
      final analysis = await _service.analyzeAppleHealthExport(
        staged.file,
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
      _pendingSource = null;
      // Never let a retry reuse a copy we already know is bad.
      await _stagingStore.clear();
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
  /// (Kotlin `importSelectedAppleHealthExport` + the worker's checkpoint /
  /// staging lifecycle).
  Future<void> importSelected() async {
    if (state.isBusy) return;
    final source = _pendingSource;
    final analysis = state.analysis;
    if (source == null || analysis == null) return;
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
      // Only a checkpoint written for this exact export *and* this exact
      // category selection may be resumed; anything else starts clean.
      final stored = await _checkpointStore.load(source.sourceKey, selected);
      final resumeCheckpoint = stored ??
          AppleHealthImportCheckpoint(
            sourceKey: source.sourceKey,
            selectedCategories: selected,
          );
      final staged = await _stagingStore.stage(source);
      // The service hands checkpoints to a synchronous callback, so the writes
      // are chained: an earlier save must never land *after* a later one and
      // wind the checkpoint backwards.
      var checkpointWrites = Future<void>.value();
      final result = await _service.importAppleHealthExport(
        staged.file,
        selectedCategories: selected,
        resumeCheckpoint: resumeCheckpoint,
        onCheckpoint: (checkpoint) {
          checkpointWrites = checkpointWrites
              .then((_) => _checkpointStore.save(checkpoint))
              .catchError((_) {
            // A checkpoint we could not persist only costs a re-import of the
            // batch; it must never fail the import itself.
          });
        },
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
      // Success: the staged copy, its metadata, any leftover `.tmp`, the
      // checkpoint and the (now empty) import directory all go away.
      await checkpointWrites;
      await _checkpointStore.clear();
      await _stagingStore.clear();
      state = AppleHealthImportUiState(
        analysis: analysis,
        selectedCategories: selected,
        result: result,
      );
    } catch (error) {
      // The staged copy and checkpoint are deliberately kept so the user can
      // retry and resume from the last committed batch.
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
