import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../domain/model/comaps_navigation.dart';
import '../../../../di/providers.dart';
import '../../../../core/result/result.dart';
import '../../../../core/presentation/command_state.dart';
import '../../../../core/presentation/screen_error.dart';
import '../../../../domain/model/activity_entry_types.dart';
import '../activity_entry_providers.dart';
import 'activity_recording.dart';
import 'activity_recording_focus_mode.dart';

part 'activity_recording_view_model.freezed.dart';

/// Shown when [ActivityRecordingController.finishRecording] finds nothing to
/// finish. Same text the activity-entry view-model has always used for that
/// case, because it is the same failure.
const String kNoActiveRecordingMessage =
    'No active activity recording was found.';

/// The SCREEN's view of a live recording.
///
/// [recording] is republished from the device-bound `ActivityRecordingService`
/// — the view-model never mutates it, it only mirrors it — while [now],
/// [isFocusMode] and the two commands are surface the screen owns and the
/// platform knows nothing about.
@freezed
abstract class ActivityRecordingUiState with _$ActivityRecordingUiState {
  const ActivityRecordingUiState._();

  const factory ActivityRecordingUiState({
    /// The last state published by the recording service.
    @Default(ActivityRecordingState()) ActivityRecordingState recording,

    /// The clock the elapsed/moving durations are read against. Ticks once a
    /// second while the session is active, and is otherwise frozen — a widget
    /// reading `DateTime.now()` itself would rebuild against a clock the state
    /// has not seen.
    DateTime? now,

    /// Focus mode is a property of the SCREEN, not of the recording: it must
    /// survive a rebuild but not a process death, and the host drops its app
    /// bar for it.
    @Default(false) bool isFocusMode,

    /// Starting a recording is failable — permissions, a missing GPS fix, an
    /// unsupported activity type — and the failure is the user's to see.
    @Default(CommandState<void>.idle()) CommandState<void> start,

    /// Stopping a recording hands back the snapshot that becomes the entry
    /// form's draft. A stop with no active session fails rather than silently
    /// producing nothing.
    @Default(CommandState<ActivityRecordingSnapshot>.idle())
    CommandState<ActivityRecordingSnapshot> save,

    /// What CoMaps is guiding the user through right now, if anything. Every
    /// value of this — including all four unavailable ones — is a normal state:
    /// the recording never depends on it.
    @Default(CoMapsNavigationDisabled())
    CoMapsNavigationState coMapsNavigation,
  }) = _ActivityRecordingUiState;

  /// The wall clock the durations are computed against, falling back to the
  /// real one before the first tick.
  DateTime get _clock => now ?? DateTime.now();

  /// Time spent actually moving — pauses removed.
  Duration get movingTime => recording.movingDuration(_clock);

  /// The headline duration. A repetition session counts its rests as part of
  /// the workout; everything else shows wall-clock elapsed time.
  Duration get totalTime => recording.recordingKind ==
          ActivityRecordingKind.repetition
      ? movingTime + recording.restDuration(_clock)
      : recording.elapsedDuration(_clock);

  /// Focus mode only exists for sessions that can use it, so the flag alone is
  /// never enough to render it. The host and the recording screen both gate on
  /// THIS, so they cannot drift into disagreeing about whether the app bar is
  /// showing.
  bool get showFocusMode => isFocusMode && canUseRecordingFocusMode(recording);

  bool get isStarting => start is CommandRunning<void>;

  bool get isSaving => save is CommandRunning<ActivityRecordingSnapshot>;

  /// The error a failed command left behind, if any. The recording's own
  /// [ActivityRecordingState.errorMessage] (a GPS glitch, a missing sensor) is
  /// a live-session warning, not a command failure, and stays where it is.
  ScreenError? get commandError => switch (start) {
        CommandFailure<void>(:final error) => error,
        _ => switch (save) {
            CommandFailure<ActivityRecordingSnapshot>(:final error) => error,
            _ => null,
          },
      };
}

/// The SCREEN side of activity recording.
///
/// Everything that touches the device — the foreground service, the
/// notification buttons, GPS/BLE/motion streams, the draft store — lives in
/// `ActivityRecordingService` (see `activity_recording_service.dart`) and is
/// deliberately NOT reachable from here except through the
/// [ActivityRecordingController] interface. This view-model subscribes to that
/// service, republishes what it emits, and adds the three things only a screen
/// has: a one-second clock, focus mode, and the command lifecycles for the two
/// actions that can fail (start and save).
class ActivityRecordingViewModel extends Notifier<ActivityRecordingUiState> {
  ActivityRecordingController get _service =>
      ref.read(activityRecordingControllerProvider);

  Timer? _ticker;

  /// CoMaps is polled, not subscribed to: a ContentProvider has no change feed,
  /// so the only way to see a turn coming is to ask. Two seconds is the Kotlin
  /// cadence — often enough that a turn instruction is not stale on screen,
  /// rarely enough to be free next to a GPS fix arriving every second.
  Timer? _coMapsPoll;
  static const Duration _coMapsPollInterval = Duration(seconds: 2);

  final CoMapsNavigationSampleRecorder _coMapsRecorder =
      CoMapsNavigationSampleRecorder();

  /// The session the banked samples belong to. When the recording restarts, the
  /// samples of the last one are not ours to keep.
  DateTime? _coMapsSessionStart;

  @override
  ActivityRecordingUiState build() {
    final service = _service;

    void listener() {
      final recording = service.state.value;
      state = state.copyWith(recording: recording, now: DateTime.now());
      _syncTicker(recording);
      _syncCoMapsPoll(recording);
    }

    service.state.addListener(listener);
    ref.onDispose(() {
      service.state.removeListener(listener);
      _ticker?.cancel();
      _ticker = null;
      _coMapsPoll?.cancel();
      _coMapsPoll = null;
    });

    final restored = service.state.value;
    // A recording restored from disk after process death is already running by
    // the time the screen asks for it, so its clock has to be ticking already.
    _syncTicker(restored);
    _syncCoMapsPoll(restored, canPublish: false);
    return ActivityRecordingUiState(
      recording: restored,
      now: DateTime.now(),
    );
  }

  /// The clock only runs while there is something to count. Mirrors the
  /// `LaunchedEffect(state.status)` the Kotlin screen ticked on.
  void _syncTicker(ActivityRecordingState recording) {
    final shouldTick = recording.isActive;
    if (shouldTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!ref.mounted) return;
        state = state.copyWith(now: DateTime.now());
      });
    } else if (!shouldTick && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  // ── CoMaps guidance ──────────────────────────────────────────────────────

  /// Guidance is only read while a GPS route is actually being recorded, and
  /// only when the user asked for it. A repetition session in a gym has nothing
  /// to navigate, and a paused recording is not going anywhere.
  bool _wantsCoMaps(ActivityRecordingState recording) {
    // The cheap questions first: there is nothing to poll for a gym session or
    // a stopped one, and no reason to reach for preferences to find that out.
    if (!recording.isActive ||
        recording.recordingKind != ActivityRecordingKind.gpsRoute) {
      return false;
    }
    return ref
        .read(preferencesRepositoryProvider)
        .activityRecordingPreferences()
        .coMapsNavigationContextEnabled;
  }

  /// [canPublish] is false while `build()` is still assembling the first state:
  /// reading `state` there is reading a notifier that does not exist yet. The
  /// initial state already says disabled, so there is nothing to publish anyway
  /// — only timers to arrange.
  void _syncCoMapsPoll(
    ActivityRecordingState recording, {
    bool canPublish = true,
  }) {
    if (!_wantsCoMaps(recording)) {
      if (_coMapsPoll != null) {
        _coMapsPoll!.cancel();
        _coMapsPoll = null;
      }
      _coMapsRecorder.reset();
      _coMapsSessionStart = null;
      if (canPublish && state.coMapsNavigation is! CoMapsNavigationDisabled) {
        state = state.copyWith(
          coMapsNavigation: const CoMapsNavigationDisabled(),
        );
      }
      return;
    }

    // A restarted recording does not inherit the last one's guidance.
    final startTime = recording.startTime;
    if (startTime != null && startTime != _coMapsSessionStart) {
      _coMapsRecorder.reset();
      _coMapsSessionStart = startTime;
    }

    if (_coMapsPoll == null) {
      unawaited(_readCoMaps());
      _coMapsPoll = Timer.periodic(
        _coMapsPollInterval,
        (_) => unawaited(_readCoMaps()),
      );
    }
  }

  Future<void> _readCoMaps() async {
    final result =
        await ref.read(coMapsNavigationRepositoryProvider).readLive();
    if (!ref.mounted) return;
    // The bridge itself failing is still only a guidance problem. It is shown
    // where the guidance goes, and the recording carries on regardless.
    final navigation = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => CoMapsNavigationError(failure.toString()),
    };
    state = state.copyWith(coMapsNavigation: navigation);

    // Bank the reading only if the user wants it kept. The recorder decides
    // whether this one is worth keeping; most are not.
    if (navigation is CoMapsNavigationActive &&
        ref.read(preferencesRepositoryProvider)
            .activityRecordingPreferences()
            .saveCoMapsNavigationContext) {
      _coMapsRecorder.accept(navigation.snapshot);
    }
  }

  /// Grants `app.comaps.permission.READ_NAVIGATION_DATA`, then reads again so
  /// the panel updates without waiting for the next poll.
  Future<void> requestCoMapsPermission() async {
    await ref.read(coMapsNavigationRepositoryProvider).requestPermission();
    if (!ref.mounted) return;
    await _readCoMaps();
  }

  /// Hands the map to CoMaps so the user can plan a route on it.
  Future<void> planInCoMaps({double? latitude, double? longitude}) async {
    await ref.read(coMapsNavigationRepositoryProvider).launchForPlanning(
          latitude: latitude,
          longitude: longitude,
        );
  }

  /// The guidance banked during this recording, for the activity about to be
  /// saved. Empty unless the user asked for it to be kept.
  List<CoMapsNavigationSnapshot> get coMapsSamples => _coMapsRecorder.samples;

  // ── Commands ─────────────────────────────────────────────────────────────

  /// Starts a session. The service decides whether it can (permissions, fix
  /// quality, activity type) and puts its reason on the recording state; this
  /// lifts that reason onto the command so the screen shows it once and clears
  /// it, instead of leaving it smeared across the form.
  Future<void> startRecording(
    ActivityEntryType activityType,
    ActivityRecordingInitialFix? initialFix, {
    int repetitionRestSeconds = 0,
  }) async {
    if (state.isStarting) return;
    final service = _service;
    state = state.copyWith(start: const CommandState.running());
    final started = await service.startRecording(
      activityType,
      initialFix,
      repetitionRestSeconds: repetitionRestSeconds,
    );
    if (!ref.mounted) return;
    final recording = service.state.value;
    state = state.copyWith(
      recording: recording,
      start: started
          ? const CommandState.success(null)
          : CommandState.failure(
              ScreenErrorMessage(
                recording.errorMessage ?? kNoActiveRecordingMessage,
              ),
            ),
    );
    _syncTicker(recording);
  }

  void pauseRecording() => _service.pauseRecording();

  void resumeRecording() => _service.resumeRecording();

  /// Stops the session and hands the snapshot to whoever is listening — it is
  /// the ONLY copy of the workout that was just recorded, so a failure to
  /// produce one is a failure the user must see, never a silent no-op.
  void stopRecording() {
    final service = _service;
    state = state.copyWith(save: const CommandState.running());
    // Take the guidance BEFORE finishing: the moment the recording goes
    // inactive the poll tears itself down and resets the recorder, and these
    // samples are the only copy.
    final coMapsSamples = _coMapsRecorder.samples;
    final finished = service.finishRecording();
    final snapshot = finished?.copyWith(coMapsNavigationSamples: coMapsSamples);
    final recording = service.state.value;
    state = state.copyWith(
      recording: recording,
      isFocusMode: snapshot == null ? state.isFocusMode : false,
      save: snapshot == null
          ? const CommandState.failure(
              ScreenErrorMessage(kNoActiveRecordingMessage),
            )
          : CommandState.success(snapshot),
    );
    _syncTicker(recording);
  }

  /// Throws the session away. Both commands go back to rest: there is nothing
  /// left for the screen to report the outcome of.
  void discardRecording() {
    final service = _service;
    service.discardRecording();
    final recording = service.state.value;
    state = state.copyWith(
      recording: recording,
      isFocusMode: false,
      start: const CommandState.idle(),
      save: const CommandState.idle(),
    );
    _syncTicker(recording);
  }

  // ── Screen-owned surface ─────────────────────────────────────────────────

  void setFocusMode(bool enabled) {
    if (enabled == state.isFocusMode) return;
    state = state.copyWith(isFocusMode: enabled);
  }

  /// The screen consumed the start outcome, so the command returns to rest —
  /// otherwise re-entering the route would replay a stale failure.
  void onStartHandled() {
    state = state.copyWith(start: const CommandState.idle());
  }

  /// The screen took the snapshot (it is now the entry form's draft), so the
  /// command returns to rest. Consuming it twice would hand the same workout
  /// to the form again.
  void onSaveHandled() {
    state = state.copyWith(save: const CommandState.idle());
  }
}

/// App-lifetime on purpose: a recording outlives the route that started it, and
/// must still be running when the user comes back to it.
final activityRecordingViewModelProvider = NotifierProvider<
    ActivityRecordingViewModel, ActivityRecordingUiState>(
  ActivityRecordingViewModel.new,
);
