import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/presentation/screen_error.dart';
import '../../di/providers.dart';
import '../../domain/model/mindfulness_models.dart';

part 'mindfulness_entry_notifier.freezed.dart';

const int _minSessionMinutes = 1;
const int _maxSessionMinutes = 24 * 60;
const String _defaultSessionTitle = 'Meditation';

/// Port of the Kotlin `MindfulnessEntryError` (manual-entry subset). The
/// timer/interval error variants live with the phase6d timer port.
enum MindfulnessEntryError {
  invalidManualEntry,
  missingWritePermission,
  unavailable,
  writeFailed,
}

/// Riverpod port of the Kotlin `MindfulnessEntryUiState`, trimmed to the MANUAL
/// duration path. The live bell/ambient timer fields are deferred to phase6d.
@freezed
abstract class MindfulnessEntryState with _$MindfulnessEntryState {
  const MindfulnessEntryState._();

  const factory MindfulnessEntryState({
    @Default('') String manualMinutesText,
    @Default(<String>{}) Set<String> writePermissions,
    @Default(false) bool canWrite,
    @Default(true) bool mindfulnessAvailable,
    @Default(true) bool isCheckingPermission,
    @Default(false) bool isSavingEntry,
    String? editRecordId,
    DateTime? editStartTime,
    @Default(false) bool saveCompleted,
    MindfulnessEntryError? entryError,
    ScreenError? writeError,
  }) = _MindfulnessEntryState;

  bool get isEditMode => editRecordId != null;
}

/// Parses a positive minute count. Port of the Kotlin `String.toPositiveIntOrNull`.
int? parsePositiveMinutes(String text) {
  final value = int.tryParse(text.trim());
  return (value != null && value > 0) ? value : null;
}

/// Riverpod port of the Kotlin `MindfulnessEntryViewModel`, manual-entry path.
///
/// The live meditation timer (start/stop/resume, interval bells, ambient sound)
/// is intentionally out of scope here.
// TODO(phase6d): port the live timer + bell/background sound path.
class MindfulnessEntryNotifier extends Notifier<MindfulnessEntryState> {
  MindfulnessEntryNotifier({this.editRecordId});

  final String? editRecordId;

  @override
  MindfulnessEntryState build() {
    Future.microtask(() async {
      if (!ref.mounted) return;
      await refreshPermission();
      if (ref.mounted) await _loadEditEntry();
    });
    return MindfulnessEntryState(editRecordId: editRecordId);
  }

  Future<void> refreshPermission() async {
    final repo = ref.read(mindfulnessRepositoryProvider);
    state = state.copyWith(
      isCheckingPermission: true,
      entryError: null,
      writeError: null,
    );
    try {
      final available = repo.isMindfulnessAvailable();
      final canWrite = await repo.hasMindfulnessWritePermission();
      if (!ref.mounted) return;
      state = state.copyWith(
        isCheckingPermission: false,
        mindfulnessAvailable: available,
        writePermissions: repo.mindfulnessWritePermissions,
        canWrite: canWrite,
        entryError: available ? null : MindfulnessEntryError.unavailable,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isCheckingPermission: false,
        mindfulnessAvailable: false,
        writePermissions: repo.mindfulnessWritePermissions,
        canWrite: false,
        entryError: MindfulnessEntryError.unavailable,
        writeError: throwableToScreenError(error),
      );
    }
  }

  void updateManualMinutes(String text) {
    state = state.copyWith(
      manualMinutesText: text,
      saveCompleted: false,
      entryError: null,
      writeError: null,
    );
  }

  void updateEntryStartTime(DateTime time) {
    final minutes = parsePositiveMinutes(state.manualMinutesText);
    state = state.copyWith(
      editStartTime: _coerceAtLatestSessionStart(time, minutes),
      saveCompleted: false,
      entryError: null,
      writeError: null,
    );
  }

  /// Validates the manual minutes + writes (or updates) a mindfulness session.
  Future<void> addManualEntry() async {
    final minutes = parsePositiveMinutes(state.manualMinutesText);
    if (minutes == null ||
        minutes < _minSessionMinutes ||
        minutes > _maxSessionMinutes) {
      state = state.copyWith(
        entryError: MindfulnessEntryError.invalidManualEntry,
        writeError: null,
      );
      return;
    }
    if (!state.mindfulnessAvailable) {
      state = state.copyWith(
        entryError: MindfulnessEntryError.unavailable,
        writeError: null,
      );
      return;
    }
    if (!state.canWrite) {
      state = state.copyWith(
        entryError: MindfulnessEntryError.missingWritePermission,
        writeError: null,
      );
      return;
    }

    final base = state.editStartTime ??
        DateTime.now().subtract(Duration(minutes: minutes));
    final start = _coerceAtLatestSessionStart(base, minutes);
    final end = start.add(Duration(minutes: minutes));

    state = state.copyWith(
      isSavingEntry: true,
      entryError: null,
      writeError: null,
    );
    final request = MindfulnessSessionWriteRequest(
      title: _defaultSessionTitle,
      startTime: start,
      endTime: end,
    );
    try {
      final repo = ref.read(mindfulnessRepositoryProvider);
      if (editRecordId == null) {
        await repo.writeMindfulnessSessionEntry(request);
      } else {
        await repo.updateMindfulnessSessionEntry(editRecordId!, request);
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        isSavingEntry: false,
        manualMinutesText: state.isEditMode ? state.manualMinutesText : '',
        saveCompleted: true,
        entryError: null,
        writeError: null,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isSavingEntry: false,
        entryError: MindfulnessEntryError.writeFailed,
        writeError: throwableToScreenError(error),
      );
    }
  }

  void onSaveCompletedHandled() {
    state = state.copyWith(saveCompleted: false);
  }

  Future<void> _loadEditEntry() async {
    final recordId = editRecordId;
    if (recordId == null) return;
    try {
      final session =
          await ref.read(mindfulnessRepositoryProvider).loadMindfulnessSession(
                recordId,
              );
      if (!ref.mounted) return;
      if (session == null || !session.isOpenVitalsEntry) {
        state = state.copyWith(
          entryError: MindfulnessEntryError.writeFailed,
          writeError: const ScreenErrorMessage(
            'Only OpenVitals entries can be edited.',
          ),
        );
        return;
      }
      final rawMinutes =
          session.endTime.difference(session.startTime).inMinutes;
      final minutes = rawMinutes
          .clamp(_minSessionMinutes, _maxSessionMinutes);
      state = state.copyWith(
        manualMinutesText: minutes.toString(),
        editStartTime:
            _coerceAtLatestSessionStart(session.startTime, minutes),
        entryError: null,
        writeError: null,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        entryError: MindfulnessEntryError.writeFailed,
        writeError: throwableToScreenError(error),
      );
    }
  }

  /// Port of the Kotlin `Instant.coerceAtLatestSessionStart`: the session start
  /// cannot be later than now minus its duration (so the whole session fits
  /// before the present moment).
  DateTime _coerceAtLatestSessionStart(DateTime time, int? minutes) {
    final durationMinutes = (minutes != null &&
            minutes >= _minSessionMinutes &&
            minutes <= _maxSessionMinutes)
        ? minutes
        : _minSessionMinutes;
    final latest = DateTime.now().subtract(Duration(minutes: durationMinutes));
    return time.isAfter(latest) ? latest : time;
  }
}
