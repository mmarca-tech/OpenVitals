/// Two-pass Apple Health import orchestration, ported from the Kotlin
/// `AppleHealthImportService.kt`.
///
/// The Kotlin service streams the export through a SAX consumer and overlaps
/// parse/convert with a duplicate-check + insert writer coroutine. This Dart
/// port keeps the same observable contract — analyze (count/summarize by
/// category without writing) and import (convert, in-file + existing dedup,
/// batched insert, shareable report) — but converts the whole parsed export in
/// one pass (`AppleHealthImportConverter.convert`) and processes the converted
/// records in sequential 300-record batches, which is simpler and matches the
/// tests. A real WorkManager-style background worker is intentionally NOT
/// ported; callers run this async service directly (e.g. from an import screen).
library;

import 'dart:async';

import '../../../data/repository/contract/apple_health_import_repository.dart';
import 'apple_health_import_categories.dart';
import 'apple_health_import_converter.dart';
import 'apple_health_import_conversion_support.dart';
import 'apple_health_import_error_formatter.dart';
import 'apple_health_import_models.dart';
import 'apple_health_import_parser.dart';
import 'apple_health_import_report_store.dart';
import 'apple_health_import_types.dart';

typedef AppleHealthImportProgressCallback = void Function(
    AppleHealthImportProgress progress);

const int _convertedBatchSize = 300;
const int _maxRawDiagnostics = 1000;
const int _maxDuplicateCheckSpanSeconds = 6 * 60 * 60;

class AppleHealthImportService {
  AppleHealthImportService(this._repository);

  final AppleHealthImportRepository _repository;

  Future<AppleHealthImportAnalysisResult> analyzeAppleHealthExport(
    List<int> bytes, {
    AppleHealthImportProgressCallback? onProgress,
  }) async {
    final importLogs = <String>[];
    void log(String message) => importLogs.add(_infoLog(message));
    final mindfulnessAvailable = _repository.isMindfulnessAvailable();
    log('Apple Health analysis requested');

    final parsed = _parseExport(
      bytes,
      importLogs,
      onProgress,
      const AppleHealthParseOptions(
        parseRouteFiles: false,
        parseRecordDetails: false,
      ),
    );

    final typeStats = <String, MutableAppleImportTypeStats>{};
    final categoryStats = <AppleHealthImportCategory, _MutableCategorySummary>{};
    final diagnostics = <AppleHealthImportDiagnostic>[];
    final diagnosticSummaries = <String, AppleHealthImportDiagnosticSummary>{};
    final rawDiagnosticTypes = <String>{};

    parsed.parsedTypeCounts.forEach((type, count) {
      _stat(typeStats, type).parsed += count;
    });

    void markUnsupported(String appleType, String detail) {
      _stat(typeStats, appleType).unsupported += 1;
      final diagnostic = AppleHealthImportDiagnostic(
        appleType: appleType,
        targetType: null,
        reasonCode: 'unsupported',
        timeRange: null,
        unit: null,
        value: null,
        detail: detail,
      );
      addToDiagnosticSummaries(diagnosticSummaries, diagnostic);
      if (rawDiagnosticTypes.add(appleType)) diagnostics.add(diagnostic);
    }

    for (final record in parsed.records) {
      final category = analysisCategory(record, mindfulnessAvailable);
      if (category != null) {
        _stat(typeStats, record.type).converted += 1;
        _addCategory(categoryStats, category, 1);
      } else {
        markUnsupported(
          record.type,
          'No direct Health Connect mapping is implemented for this Apple '
              'record type.',
        );
      }
    }
    for (final workout in parsed.workouts) {
      _stat(typeStats, workout.workoutActivityType).converted += 1;
      _addCategory(
        categoryStats,
        AppleHealthImportCategory.workouts,
        1,
        routeSessions: workout.routeReferences > 0 ? 1 : 0,
      );
    }
    for (final correlation in parsed.correlations) {
      if (correlation.type == appleBloodPressureCorrelation) {
        _stat(typeStats, correlation.type).converted += 1;
        _addCategory(categoryStats, AppleHealthImportCategory.vitals, 1);
      } else {
        markUnsupported(
          correlation.type,
          'Correlation type has no direct Health Connect import mapping.',
        );
      }
    }
    for (var i = 0; i < parsed.parsedActivitySummaries; i++) {
      markUnsupported(
        'ActivitySummary',
        'Apple activity rings and stand hours have no direct writable Health '
            'Connect record.',
      );
    }

    final summaries = _toTypeSummaries(typeStats);
    final totals = _totals(summaries);
    final categorySummaries = _categorySummaries(categoryStats);
    onProgress?.call(_progress(
      AppleHealthImportPhase.buildingReport,
      parsed: parsed,
      converted: totals.converted,
      unsupported: totals.unsupported,
    ));
    final reportText = _buildReportText(
      parsed: parsed,
      imported: 0,
      selectedCategories: null,
      summaries: summaries,
      categorySummaries: categorySummaries,
      diagnostics: diagnostics,
      diagnosticSummaries: diagnosticSummaries.values.toList(),
      importLogs: importLogs,
    );
    return AppleHealthImportAnalysisResult(
      parsedRecords: parsed.parsedRecords,
      parsedWorkouts: parsed.parsedWorkouts,
      parsedCorrelations: parsed.parsedCorrelations,
      parsedActivitySummaries: parsed.parsedActivitySummaries,
      convertedRecords: totals.converted,
      unsupportedElements: totals.unsupported,
      skippedRecords: totals.skipped,
      failedRecords: totals.failed,
      categorySummaries: categorySummaries,
      typeSummaries: summaries,
      diagnostics: diagnostics,
      shareableReportText: reportText,
    );
  }

  Future<AppleHealthImportResult> importAppleHealthExport(
    List<int> bytes, {
    Set<AppleHealthImportCategory> selectedCategories =
        allAppleHealthImportCategories,
    AppleHealthImportProgressCallback? onProgress,
  }) async {
    final importLogs = <String>[];
    void log(String message) => importLogs.add(_infoLog(message));
    log('Apple Health import requested selectedCategories='
        '${selectedCategories.map((c) => c.name).join(', ')}');

    final converter = AppleHealthImportConverter(
      mindfulnessAvailable: _repository.isMindfulnessAvailable(),
      diagnosticLimit: _maxRawDiagnostics,
    );
    final typeStats = converter.typeStats;

    final parsed = _parseExport(
      bytes,
      importLogs,
      onProgress,
      // Kotlin 1.9.0 (a852d4e): don't read the workout-routes/*.gpx entries at
      // all when Workouts is deselected. A sleep/body/vitals-only import is much
      // faster, and a damaged route entry can no longer fail an import that never
      // wanted routes.
      AppleHealthParseOptions(
        parseRouteFiles:
            selectedCategories.contains(AppleHealthImportCategory.workouts),
      ),
    );

    onProgress?.call(_progress(AppleHealthImportPhase.converting, parsed: parsed));
    log('Stage started: Converting records');
    final conversion = converter.convert(parsed);
    final convertedCount = conversion.converted.length;
    final conversionTotals = _totals(_toTypeSummaries(typeStats));
    log('Stage finished: Converting records converted=${conversionTotals.converted} '
        'unsupported=${conversionTotals.unsupported} skipped=${conversionTotals.skipped} '
        'failed=${conversionTotals.failed}');

    // Classify + select. Category stats include not-selected records (Kotlin).
    final categoryStats = <AppleHealthImportCategory, _MutableCategorySummary>{};
    final selected = <ConvertedAppleRecord>[];
    for (final converted in conversion.converted) {
      final category = importCategory(converted);
      _addCategory(
        categoryStats,
        category,
        1,
        routeSessions: convertedHasExerciseRoute(converted) ? 1 : 0,
      );
      if (!selectedCategories.contains(category)) {
        _stat(typeStats, converted.appleType).notSelected += 1;
        continue;
      }
      selected.add(converted);
    }

    final serviceDiagnostics = <AppleHealthImportDiagnostic>[];
    final serviceDiagnosticSummaries =
        <String, AppleHealthImportDiagnosticSummary>{};
    var imported = 0;
    var duplicate = 0;
    var failed = 0;
    var notSelected = _totals(_toTypeSummaries(typeStats)).notSelected;

    for (final batch in _chunked(selected, _convertedBatchSize)) {
      onProgress?.call(_progress(
        AppleHealthImportPhase.checkingDuplicates,
        parsed: parsed,
        converted: convertedCount,
        imported: imported,
        duplicate: duplicate,
        notSelected: notSelected,
        failed: failed,
      ));
      log('Stage started: Checking duplicates batchRecords=${batch.length}');
      final deduplicated = _deduplicateWithinImport(
        batch,
        serviceDiagnostics,
        serviceDiagnosticSummaries,
        typeStats,
      );
      final inFileDuplicates = batch.length - deduplicated.length;
      if (inFileDuplicates > 0) {
        duplicate += inFileDuplicates;
        log('Skipped duplicate records inside export count=$inFileDuplicates');
      }
      final existingIds = await _findExistingClientRecordIds(deduplicated, importLogs);
      final toInsert = <ConvertedAppleRecord>[];
      for (final converted in deduplicated) {
        final clientRecordId = converted.clientRecordId;
        final isDuplicate =
            clientRecordId != null && existingIds.contains(clientRecordId);
        if (isDuplicate) {
          _addServiceDiagnostic(
            serviceDiagnostics,
            serviceDiagnosticSummaries,
            converted,
            'duplicate_existing',
            'A matching Health Connect clientRecordId already exists.',
          );
          _stat(typeStats, converted.appleType).duplicateSkipped += 1;
          duplicate += 1;
        } else {
          toInsert.add(converted);
        }
      }
      final existingDuplicates = deduplicated.length - toInsert.length;
      if (existingDuplicates > 0) {
        log('Skipped records already present in Health Connect count=$existingDuplicates');
      }
      log('Stage finished: Checking duplicates batchRecords=${batch.length} '
          'unique=${deduplicated.length} toInsert=${toInsert.length} '
          'inFileDuplicates=$inFileDuplicates existingDuplicates=$existingDuplicates');

      onProgress?.call(_progress(
        AppleHealthImportPhase.writing,
        parsed: parsed,
        converted: convertedCount,
        imported: imported,
        duplicate: duplicate,
        notSelected: notSelected,
        failed: failed,
      ));
      log('Stage started: Writing records attempted=${toInsert.length}');
      final result = await _insertConvertedRecords(
        toInsert,
        serviceDiagnostics,
        serviceDiagnosticSummaries,
        typeStats,
        importLogs,
      );
      imported += result.imported;
      duplicate += result.duplicates;
      failed += result.failed;
      log('Stage finished: Writing records attempted=${toInsert.length} '
          'imported=${result.imported} duplicates=${result.duplicates} '
          'failed=${result.failed}');
      onProgress?.call(_progress(
        AppleHealthImportPhase.writing,
        parsed: parsed,
        converted: convertedCount,
        imported: imported,
        duplicate: duplicate,
        notSelected: notSelected,
        failed: failed,
      ));
    }

    final summaries = _toTypeSummaries(typeStats);
    final totals = _totals(summaries);
    notSelected = totals.notSelected;
    final diagnostics = [
      ...converter.diagnosticsSnapshot(),
      ...serviceDiagnostics,
    ];
    final diagnosticSummaries = _mergeDiagnosticSummaries([
      ...converter.diagnosticSummariesSnapshot(),
      ...serviceDiagnosticSummaries.values,
    ]);
    final categorySummaries = _categorySummaries(categoryStats);
    log('Import completed converted=${totals.converted} imported=$imported '
        'duplicates=${totals.duplicateSkipped} unsupported=${totals.unsupported} '
        'notSelected=${totals.notSelected} skipped=${totals.skipped} '
        'failed=${totals.failed} diagnostics=${diagnostics.length}');
    onProgress?.call(_progress(
      AppleHealthImportPhase.buildingReport,
      parsed: parsed,
      converted: convertedCount,
      imported: imported,
      duplicate: totals.duplicateSkipped,
      notSelected: totals.notSelected,
      unsupported: totals.unsupported,
      skipped: totals.skipped,
      failed: totals.failed,
    ));
    log('Stage started: Building report diagnostics=${diagnostics.length} '
        'diagnosticGroups=${diagnosticSummaries.length} typeSummaries=${summaries.length}');
    log('Stage finished: Building report');
    final reportText = _buildReportText(
      parsed: parsed,
      imported: imported,
      selectedCategories: selectedCategories,
      summaries: summaries,
      categorySummaries: categorySummaries,
      diagnostics: diagnostics,
      diagnosticSummaries: diagnosticSummaries,
      importLogs: importLogs,
    );
    return AppleHealthImportResult(
      parsedRecords: parsed.parsedRecords,
      parsedWorkouts: parsed.parsedWorkouts,
      parsedCorrelations: parsed.parsedCorrelations,
      parsedActivitySummaries: parsed.parsedActivitySummaries,
      convertedRecords: totals.converted,
      importedRecords: imported,
      duplicateSkippedRecords: totals.duplicateSkipped,
      notSelectedRecords: totals.notSelected,
      unsupportedElements: totals.unsupported,
      skippedRecords: totals.skipped,
      failedRecords: totals.failed,
      typeSummaries: summaries,
      diagnostics: diagnostics,
      shareableReportText: reportText,
    );
  }

  AppleParsedExport _parseExport(
    List<int> bytes,
    List<String> importLogs,
    AppleHealthImportProgressCallback? onProgress,
    AppleHealthParseOptions options,
  ) {
    onProgress?.call(const AppleHealthImportProgress(
      phase: AppleHealthImportPhase.parsing,
    ));
    importLogs.add(_infoLog(
      'Stage started: Scanning export parseRouteFiles=${options.parseRouteFiles} '
      'parseRecordDetails=${options.parseRecordDetails}',
    ));
    final parsed = AppleHealthImportParser.parse(bytes, options: options);
    importLogs.add(_infoLog(
      'Stage finished: Scanning export records=${parsed.parsedRecords} '
      'workouts=${parsed.parsedWorkouts} correlations=${parsed.parsedCorrelations} '
      'activitySummaries=${parsed.parsedActivitySummaries}',
    ));
    if (parsed.sanitizedControlChars > 0 || parsed.sanitizedAmpersands > 0) {
      importLogs.add(_infoLog(
        'export.xml contained invalid XML that was auto-repaired: '
        'controlCharsRemoved=${parsed.sanitizedControlChars} '
        'ampersandsEscaped=${parsed.sanitizedAmpersands}',
      ));
    }
    return parsed;
  }

  Future<Set<String>> _findExistingClientRecordIds(
    List<ConvertedAppleRecord> records,
    List<String> importLogs,
  ) async {
    final byType = <String, List<ConvertedAppleRecord>>{};
    for (final record in records) {
      if (record.clientRecordId == null) continue;
      byType.putIfAbsent(record.recordType, () => []).add(record);
    }
    final result = <String>{};
    for (final entry in byType.entries) {
      for (final chunk
          in _chunkForDuplicateCheck(entry.value, _maxDuplicateCheckSpanSeconds)) {
        final wantedIds =
            chunk.map((it) => it.clientRecordId!).toSet();
        if (wantedIds.isEmpty) continue;
        final start = chunk
            .map((it) => it.sourceTimeRange.start)
            .reduce((a, b) => a.isBefore(b) ? a : b)
            .subtract(const Duration(seconds: 1));
        final end = chunk
            .map((it) => it.sourceTimeRange.end)
            .reduce((a, b) => a.isAfter(b) ? a : b)
            .add(const Duration(seconds: 1));
        try {
          final matched = await _repository.findMatchingImportedClientRecordIds(
            entry.key,
            start,
            end,
            wantedIds,
          );
          result.addAll(matched);
        } catch (error) {
          importLogs.add(_errorLog(
            'Existing clientRecordId lookup failed recordType=${entry.key} '
            'wanted=${wantedIds.length}',
            error,
          ));
        }
      }
    }
    return result;
  }

  Future<_InsertionResult> _insertConvertedRecords(
    List<ConvertedAppleRecord> records,
    List<AppleHealthImportDiagnostic> diagnostics,
    Map<String, AppleHealthImportDiagnosticSummary> diagnosticSummaries,
    Map<String, MutableAppleImportTypeStats> typeStats,
    List<String> importLogs,
  ) async {
    if (records.isEmpty) return const _InsertionResult();
    try {
      await _repository
          .insertImportedRecords(records.map((it) => it.record).toList());
      for (final converted in records) {
        _stat(typeStats, converted.appleType).imported += 1;
      }
      return _InsertionResult(imported: records.length);
    } catch (error) {
      importLogs.add(_errorLog(
        'Batch insert failed count=${records.length}; retrying individually',
        error,
      ));
    }

    var imported = 0;
    var duplicates = 0;
    var failed = 0;
    for (final converted in records) {
      try {
        await _repository.insertImportedRecords([converted.record]);
        _stat(typeStats, converted.appleType).imported += 1;
        imported += 1;
      } catch (error) {
        if (_isDuplicateClientRecordFailure(error)) {
          _stat(typeStats, converted.appleType).duplicateSkipped += 1;
          _addServiceDiagnostic(
            diagnostics,
            diagnosticSummaries,
            converted,
            'duplicate_rejected',
            'Health Connect rejected this as an existing clientRecordId.',
          );
          duplicates += 1;
        } else {
          _stat(typeStats, converted.appleType).failed += 1;
          importLogs.add(_errorLog(
            'Record insert failed appleType=${converted.appleType} '
            'target=${converted.targetType} timeRange=${converted.sourceTimeRange}',
            error,
          ));
          _addServiceDiagnostic(
            diagnostics,
            diagnosticSummaries,
            converted,
            'insert_failed',
            AppleHealthImportErrorFormatter.details(error),
          );
          failed += 1;
        }
      }
    }
    return _InsertionResult(
      imported: imported,
      duplicates: duplicates,
      failed: failed,
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

MutableAppleImportTypeStats _stat(
  Map<String, MutableAppleImportTypeStats> typeStats,
  String type,
) =>
    typeStats.putIfAbsent(type, MutableAppleImportTypeStats.new);

class _MutableCategorySummary {
  _MutableCategorySummary(this.category);

  final AppleHealthImportCategory category;
  int convertedRecords = 0;
  int routeSessions = 0;
}

void _addCategory(
  Map<AppleHealthImportCategory, _MutableCategorySummary> categoryStats,
  AppleHealthImportCategory category,
  int convertedRecords, {
  int routeSessions = 0,
}) {
  final summary =
      categoryStats.putIfAbsent(category, () => _MutableCategorySummary(category));
  summary.convertedRecords += convertedRecords;
  summary.routeSessions += routeSessions;
}

List<AppleHealthImportCategorySummary> _categorySummaries(
  Map<AppleHealthImportCategory, _MutableCategorySummary> categoryStats,
) =>
    AppleHealthImportCategory.values
        .map((category) => categoryStats[category])
        .whereType<_MutableCategorySummary>()
        .where((summary) => summary.convertedRecords > 0)
        .map((summary) => AppleHealthImportCategorySummary(
              category: summary.category,
              convertedRecords: summary.convertedRecords,
              routeSessions: summary.routeSessions,
            ))
        .toList();

class _Totals {
  const _Totals({
    this.converted = 0,
    this.duplicateSkipped = 0,
    this.notSelected = 0,
    this.unsupported = 0,
    this.skipped = 0,
    this.failed = 0,
  });

  final int converted;
  final int duplicateSkipped;
  final int notSelected;
  final int unsupported;
  final int skipped;
  final int failed;
}

_Totals _totals(List<AppleHealthImportTypeSummary> summaries) {
  var converted = 0;
  var duplicateSkipped = 0;
  var notSelected = 0;
  var unsupported = 0;
  var skipped = 0;
  var failed = 0;
  for (final summary in summaries) {
    converted += summary.converted;
    duplicateSkipped += summary.duplicateSkipped;
    notSelected += summary.notSelected;
    unsupported += summary.unsupported;
    skipped += summary.skipped;
    failed += summary.failed;
  }
  return _Totals(
    converted: converted,
    duplicateSkipped: duplicateSkipped,
    notSelected: notSelected,
    unsupported: unsupported,
    skipped: skipped,
    failed: failed,
  );
}

List<AppleHealthImportTypeSummary> _toTypeSummaries(
  Map<String, MutableAppleImportTypeStats> typeStats,
) {
  final entries = typeStats.entries.toList()
    ..sort((a, b) {
      final byParsed = b.value.parsed.compareTo(a.value.parsed);
      if (byParsed != 0) return byParsed;
      return a.key.compareTo(b.key);
    });
  return entries
      .map((entry) => AppleHealthImportTypeSummary(
            appleType: entry.key,
            parsed: entry.value.parsed,
            converted: entry.value.converted,
            imported: entry.value.imported,
            duplicateSkipped: entry.value.duplicateSkipped,
            notSelected: entry.value.notSelected,
            unsupported: entry.value.unsupported,
            skipped: entry.value.skipped,
            failed: entry.value.failed,
          ))
      .toList();
}

List<ConvertedAppleRecord> _deduplicateWithinImport(
  List<ConvertedAppleRecord> batch,
  List<AppleHealthImportDiagnostic> diagnostics,
  Map<String, AppleHealthImportDiagnosticSummary> diagnosticSummaries,
  Map<String, MutableAppleImportTypeStats> typeStats,
) {
  final seen = <String>{};
  final result = <ConvertedAppleRecord>[];
  for (final converted in batch) {
    final key = converted.clientRecordId ?? converted.fingerprint;
    if (!seen.add(key)) {
      _addServiceDiagnostic(
        diagnostics,
        diagnosticSummaries,
        converted,
        'duplicate_in_file',
        'The export contained another object with the same deterministic import '
            'fingerprint.',
      );
      _stat(typeStats, converted.appleType).duplicateSkipped += 1;
    } else {
      result.add(converted);
    }
  }
  return result;
}

void _addServiceDiagnostic(
  List<AppleHealthImportDiagnostic> diagnostics,
  Map<String, AppleHealthImportDiagnosticSummary> diagnosticSummaries,
  ConvertedAppleRecord converted,
  String reasonCode,
  String detail,
) {
  final diagnostic = AppleHealthImportDiagnostic(
    appleType: converted.appleType,
    targetType: converted.targetType,
    reasonCode: reasonCode,
    timeRange: converted.sourceTimeRange.toString(),
    unit: converted.unit,
    value: converted.value,
    detail: detail,
  );
  addToDiagnosticSummaries(diagnosticSummaries, diagnostic);
  if (diagnostics.length < _maxRawDiagnostics) diagnostics.add(diagnostic);
}

List<AppleHealthImportDiagnosticSummary> _mergeDiagnosticSummaries(
  List<AppleHealthImportDiagnosticSummary> summaries,
) {
  final merged = <String, AppleHealthImportDiagnosticSummary>{};
  for (final summary in summaries) {
    final key = '${summary.appleType} ${summary.targetType ?? ''}'
        ' ${summary.reasonCode} ${summary.detail}';
    final existing = merged[key];
    if (existing != null) {
      existing.count += summary.count;
    } else {
      merged[key] = AppleHealthImportDiagnosticSummary(
        appleType: summary.appleType,
        targetType: summary.targetType,
        reasonCode: summary.reasonCode,
        detail: summary.detail,
        count: summary.count,
        exampleTimeRange: summary.exampleTimeRange,
        exampleUnit: summary.exampleUnit,
        exampleValue: summary.exampleValue,
      );
    }
  }
  return merged.values.toList();
}

List<List<ConvertedAppleRecord>> _chunkForDuplicateCheck(
  List<ConvertedAppleRecord> records,
  int maxSpanSeconds,
) {
  if (records.isEmpty) return const [];
  final sorted = List<ConvertedAppleRecord>.of(records)
    ..sort((a, b) => a.sourceTimeRange.start.compareTo(b.sourceTimeRange.start));
  final chunks = <List<ConvertedAppleRecord>>[];
  var current = <ConvertedAppleRecord>[sorted.first];
  var chunkStart = sorted.first.sourceTimeRange.start;
  for (var index = 1; index < sorted.length; index++) {
    final record = sorted[index];
    final spanSeconds =
        record.sourceTimeRange.start.difference(chunkStart).inSeconds;
    if (spanSeconds > maxSpanSeconds) {
      chunks.add(current);
      current = [record];
      chunkStart = record.sourceTimeRange.start;
    } else {
      current.add(record);
    }
  }
  chunks.add(current);
  return chunks;
}

List<List<T>> _chunked<T>(List<T> items, int size) {
  final chunks = <List<T>>[];
  for (var index = 0; index < items.length; index += size) {
    chunks.add(items.sublist(
      index,
      index + size > items.length ? items.length : index + size,
    ));
  }
  return chunks;
}

bool _isDuplicateClientRecordFailure(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('clientrecordid') ||
      text.contains('client record id') ||
      ((text.contains('duplicate') ||
              text.contains('already exist') ||
              text.contains('already exists')) &&
          text.contains('record'));
}

AppleHealthImportProgress _progress(
  AppleHealthImportPhase phase, {
  required AppleParsedExport parsed,
  int converted = 0,
  int imported = 0,
  int duplicate = 0,
  int notSelected = 0,
  int unsupported = 0,
  int skipped = 0,
  int failed = 0,
}) =>
    AppleHealthImportProgress(
      phase: phase,
      parsedRecords: parsed.parsedRecords,
      parsedWorkouts: parsed.parsedWorkouts,
      parsedCorrelations: parsed.parsedCorrelations,
      parsedActivitySummaries: parsed.parsedActivitySummaries,
      convertedRecords: converted,
      importedRecords: imported,
      duplicateSkippedRecords: duplicate,
      notSelectedRecords: notSelected,
      unsupportedElements: unsupported,
      skippedRecords: skipped,
      failedRecords: failed,
    );

String _infoLog(String message) =>
    '${DateTime.now().toUtc().toIso8601String()} [INFO] $message';

String _errorLog(String message, Object error) =>
    '${DateTime.now().toUtc().toIso8601String()} [ERROR] $message\n'
    '${AppleHealthImportErrorFormatter.details(error)}';

class _InsertionResult {
  const _InsertionResult({
    this.imported = 0,
    this.duplicates = 0,
    this.failed = 0,
  });

  final int imported;
  final int duplicates;
  final int failed;
}

String _buildReportText({
  required AppleParsedExport parsed,
  required int imported,
  required Set<AppleHealthImportCategory>? selectedCategories,
  required List<AppleHealthImportTypeSummary> summaries,
  required List<AppleHealthImportCategorySummary> categorySummaries,
  required List<AppleHealthImportDiagnostic> diagnostics,
  required List<AppleHealthImportDiagnosticSummary> diagnosticSummaries,
  required List<String> importLogs,
}) {
  final totals = _totals(summaries);
  final buffer = StringBuffer()
    ..writeln(appleHealthReportHeader())
    ..writeln()
    ..writeln('Summary')
    ..writeln('Parsed records: ${parsed.parsedRecords}')
    ..writeln('Parsed workouts: ${parsed.parsedWorkouts}')
    ..writeln('Parsed correlations: ${parsed.parsedCorrelations}')
    ..writeln('Parsed activity summaries: ${parsed.parsedActivitySummaries}')
    ..writeln('Converted Health Connect records: ${totals.converted}')
    ..writeln('Imported Health Connect records: $imported')
    ..writeln('Duplicate skipped: ${totals.duplicateSkipped}')
    ..writeln('Not selected: ${totals.notSelected}')
    ..writeln('Unsupported: ${totals.unsupported}')
    ..writeln('Skipped: ${totals.skipped}')
    ..writeln('Failed: ${totals.failed}');
  if (selectedCategories != null) {
    buffer.writeln(
        'Selected categories: ${selectedCategories.map((c) => c.reportName).join(', ')}');
  }
  buffer
    ..writeln()
    ..writeln('Logs');
  if (importLogs.isEmpty) {
    buffer.writeln('No import log entries were recorded.');
  } else {
    for (final entry in importLogs) {
      buffer.writeln(entry);
    }
  }
  buffer
    ..writeln()
    ..writeln('By Import Category');
  if (categorySummaries.isEmpty) {
    buffer.writeln('No Health Connect-compatible categories were detected.');
  } else {
    for (final summary in categorySummaries) {
      final routeText = summary.routeSessions > 0
          ? ', routeSessions=${summary.routeSessions}'
          : '';
      buffer.writeln(
          '- ${summary.category.reportName}: converted=${summary.convertedRecords}$routeText');
    }
  }
  buffer
    ..writeln()
    ..writeln('By Apple Type');
  for (final summary in summaries) {
    buffer.writeln(
      '- ${summary.appleType}: parsed=${summary.parsed}, converted=${summary.converted}, '
      'imported=${summary.imported}, duplicate=${summary.duplicateSkipped}, '
      'notSelected=${summary.notSelected}, unsupported=${summary.unsupported}, '
      'skipped=${summary.skipped}, failed=${summary.failed}',
    );
  }
  buffer
    ..writeln()
    ..writeln('Diagnostic Summary');
  if (diagnosticSummaries.isEmpty) {
    buffer.writeln(
        'No failures, skips, duplicates, or unsupported entries were recorded.');
  } else {
    final reasonSummaries = <String, int>{};
    for (final summary in diagnosticSummaries) {
      reasonSummaries[summary.reasonCode] =
          (reasonSummaries[summary.reasonCode] ?? 0) + summary.count;
    }
    final sortedReasons = reasonSummaries.keys.toList()..sort();
    buffer.writeln(
      'Grouped diagnostic types: ${diagnosticSummaries.length}; '
      '${sortedReasons.map((reason) => '$reason=${reasonSummaries[reason]}').join(', ')}',
    );
    final sorted = List<AppleHealthImportDiagnosticSummary>.of(diagnosticSummaries)
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        final byReason = a.reasonCode.compareTo(b.reasonCode);
        if (byReason != 0) return byReason;
        return a.appleType.compareTo(b.appleType);
      });
    for (var index = 0; index < sorted.length; index++) {
      final diagnostic = sorted[index];
      final exampleParts = <String>[
        if (diagnostic.exampleTimeRange != null)
          'exampleTime=${diagnostic.exampleTimeRange}',
        if (diagnostic.exampleUnit != null) 'unit=${diagnostic.exampleUnit}',
        if (diagnostic.exampleValue != null) 'value=${diagnostic.exampleValue}',
      ];
      final exampleText =
          exampleParts.isEmpty ? '' : '; ${exampleParts.join('; ')}';
      buffer.writeln(
        '${index + 1}. count=${diagnostic.count}; reason=${diagnostic.reasonCode}; '
        'appleType=${diagnostic.appleType}; target=${diagnostic.targetType ?? 'none'}; '
        'detail=${diagnostic.detail}$exampleText',
      );
    }
  }
  buffer
    ..writeln()
    ..writeln('Raw Diagnostic Log');
  if (diagnostics.isEmpty) {
    buffer.writeln('No raw diagnostics were recorded.');
  } else {
    if (diagnostics.length >= _maxRawDiagnostics) {
      buffer.writeln(
        'Raw diagnostics were capped at $_maxRawDiagnostics per source; '
        'see Diagnostic Summary above for complete counts.',
      );
    }
    for (var index = 0; index < diagnostics.length; index++) {
      final diagnostic = diagnostics[index];
      buffer.writeln(
        '${index + 1}. reason=${diagnostic.reasonCode}; appleType=${diagnostic.appleType}; '
        'target=${diagnostic.targetType ?? 'none'}; timeRange=${diagnostic.timeRange ?? 'none'}; '
        'unit=${diagnostic.unit ?? 'none'}; value=${diagnostic.value ?? 'none'}; '
        'detail=${diagnostic.detail}',
      );
    }
  }
  return buffer.toString();
}
