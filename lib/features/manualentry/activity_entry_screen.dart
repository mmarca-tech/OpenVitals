import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/unit_formatter.dart';
import '../../di/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../navigation/app_routes.dart';
import '../../state/app_providers.dart';
import 'activity/activity_entry_clock.dart';
import 'activity/activity_entry_form.dart';
import 'activity/activity_entry_notifier.dart';
import 'activity/activity_entry_providers.dart';
import 'activity/activity_entry_source_card.dart';
import 'activity/activity_entry_state.dart';
import 'activity/activity_entry_ui_text.dart';
import 'activity/routeimport/activity_route_import_types.dart';
import 'activity/activity_plan_picker_cards.dart';
import 'activity/recording/activity_recording.dart';
import 'manual_entry_form_scaffold.dart';

/// Activity manual-entry screen. Riverpod + Flutter port of the Kotlin
/// `ActivityEntryScreen` / `ActivityEntryFormContent`. Backs the new-entry route
/// (optional [mode] / [planId] / [activityTypeId] intents) and the edit route
/// ([activityEntryId]).
class ActivityEntryScreen extends ConsumerStatefulWidget {
  const ActivityEntryScreen({
    super.key,
    this.mode,
    this.planId,
    this.activityTypeId,
    this.activityEntryId,
  });

  final ActivityEntryMode? mode;
  final String? planId;
  final String? activityTypeId;
  final String? activityEntryId;

  @override
  ConsumerState<ActivityEntryScreen> createState() =>
      _ActivityEntryScreenState();
}

class _ActivityEntryScreenState extends ConsumerState<ActivityEntryScreen>
    with RefreshPermissionOnResume {
  late final ActivityEntryController _controller;
  final _controllers = ActivityEntryTextControllers();

  @override
  void refreshPermission() => _controller.refreshPermission();

  @override
  void initState() {
    super.initState();
    _controller = ActivityEntryController(
      repository: ref.read(activityRepositoryProvider),
      heartRepository: ref.read(heartRepositoryProvider),
      routeFileImporter: ref.read(routeFileImporterProvider),
      activityRecorder: ref.read(activityRecordingControllerProvider),
      recordingDraftStore: ref.read(activityRecordingDraftStoreProvider),
      preferencesRepository: ref.read(preferencesRepositoryProvider),
      markerRepository: ref.read(activityMarkerRepositoryProvider),
      clock: ActivityEntryClock.system(),
      editActivityId: widget.activityEntryId,
      launchMode: widget.mode?.value,
      launchPlanId: widget.planId,
      launchActivityTypeId: widget.activityTypeId,
    );
    _controller.uiState.addListener(_onStateChanged);
    _controllers.syncFrom(_controller.value);
    if (widget.activityEntryId != null) {
      _controller.loadEditEntry(ref.read(unitSystemProvider));
    }
  }

  @override
  void dispose() {
    _controller.uiState.removeListener(_onStateChanged);
    _controller.dispose();
    _controllers.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final state = _controller.value;
    _controllers.syncFrom(state);
    if (!state.saveCompleted || !mounted) return;
    _controller.onSaveCompletedHandled();
    // The write already landed; leave the entry route as the Kotlin
    // `onEntrySaved` does.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  /// Kotlin `performSourceActionAfterPermission`: every source action is gated
  /// on the Health Connect write permission, and only runs once it is granted.
  Future<void> _onSourceAction(ActivityEntrySourceAction action) async {
    if (!_controller.value.canWrite) {
      await ref
          .read(healthRepositoryProvider)
          .requestPermissions(_controller.value.writePermissions);
      _controller.refreshPermission();
      if (!mounted || !_controller.value.canWrite) return;
    }
    await _performSourceAction(action);
  }

  Future<void> _performSourceAction(ActivityEntrySourceAction action) async {
    switch (action) {
      case ActivityEntrySourceAction.manual:
        _controller.startManualEntry();
      case ActivityEntrySourceAction.existingPlan:
        _controller.startFromExistingPlan();
      case ActivityEntrySourceAction.importRouteFile:
        await _importRouteFile();
      case ActivityEntrySourceAction.recordGps:
        // The runtime location / notification / activity-recognition prompts
        // Kotlin launches here belong with the recording pass; the controller
        // reports whichever permission is missing once it tries to start.
        _controller.prepareGpsRecording();
    }
  }

  /// Kotlin launches `ActivityResultContracts.OpenDocument()` with
  /// `RouteImportMimeTypes`; `openFile` is the same SAF picker underneath.
  Future<void> _importRouteFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Routes',
          mimeTypes: kRouteImportMimeTypes,
          extensions: ['gpx', 'kml', 'kmz', 'fit'],
        ),
      ],
    );
    if (file == null) return;
    // The parsers take bytes: a content:// URI is not a readable path.
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    _controller.importRouteFile(
      ActivityRouteFileHandle(bytes: bytes, fileName: file.name),
      ref.read(unitSystemProvider),
    );
  }

  Future<void> _requestWritePermission() async {
    await ref
        .read(healthRepositoryProvider)
        .requestPermissions(_controller.value.writePermissions);
    _controller.refreshPermission();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = ref.watch(unitFormatterProvider);

    return ValueListenableBuilder<ActivityEntryUiState>(
      valueListenable: _controller.uiState,
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.manualEntryActivityTitle)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _content(state, formatter),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Kotlin `ActivityEntryFormContent`'s mode switch.
  Widget _content(ActivityEntryUiState state, UnitFormatter formatter) {
    switch (state.mode) {
      case ActivityEntryFormMode.recording:
        return _ActivityRecordingPlaceholder(controller: _controller, state: state);
      case ActivityEntryFormMode.chooseSource:
        return ActivityEntrySourceCard(
          state: state,
          onSourceAction: _onSourceAction,
          onRequestWritePermission: _requestWritePermission,
        );
      case ActivityEntryFormMode.planActivityPicker:
        return ActivityPlanActivityPickerCard(
          state: state,
          onSelectActivity: _controller.selectPlannedWorkoutActivity,
          onChooseSource: _controller.chooseSource,
        );
      case ActivityEntryFormMode.planPicker:
        return ActivityPlanPickerCard(
          state: state,
          onSelectPlan: _controller.applyPlannedWorkout,
          onChooseActivity: _controller.choosePlannedWorkoutActivity,
        );
      case ActivityEntryFormMode.manual:
      case ActivityEntryFormMode.routeImport:
        return ActivityEntryCard(
          state: state,
          unitFormatter: formatter,
          controllers: _controllers,
          callbacks: _callbacks(),
        );
    }
  }

  ActivityEntryCardCallbacks _callbacks() {
    final unitSystem = ref.read(unitSystemProvider);
    return ActivityEntryCardCallbacks(
      onSelectActivityType: _controller.selectActivityType,
      onTitleChanged: _controller.updateTitle,
      onFeelingChanged: _controller.updateFeeling,
      onNotesChanged: _controller.updateNotes,
      onStartDateChanged: _controller.updateStartDate,
      onStartTimeChanged: _controller.updateStartTime,
      onDurationChanged: _controller.updateDurationMinutes,
      onRepetitionModeChanged: _controller.updateRepetitionMode,
      onRepetitionTotalChanged: _controller.updateRepetitionTotal,
      onRepetitionSetRepetitionsChanged:
          _controller.updateRepetitionSetRepetitions,
      onRepetitionSetRestChanged: _controller.updateRepetitionSetRest,
      onAddRepetitionSet: _controller.addRepetitionSet,
      onRemoveRepetitionSet: _controller.removeRepetitionSet,
      onCreateNewPlannedWorkout: _controller.createNewPlannedWorkout,
      onApplyPlannedWorkout: _controller.applyPlannedWorkout,
      onSavePlannedWorkout: () =>
          _controller.saveCurrentAsPlannedWorkout(unitSystem),
      onUpdatePlannedWorkout: () => _controller.saveCurrentAsPlannedWorkout(
        unitSystem,
        updateSelected: true,
      ),
      onDistanceChanged: _controller.updateDistance,
      onElevationChanged: _controller.updateElevation,
      onActiveCaloriesChanged: _controller.updateActiveCalories,
      onTotalCaloriesChanged: _controller.updateTotalCalories,
      onClearRoute: _controller.clearImportedRoute,
      onChooseSource: _controller.chooseSource,
      onRequestWritePermission: _requestWritePermission,
      onAddEntry: () => _controller.addEntry(unitSystem),
      onDiscardRecordingDraft: _controller.discardRecordingDraft,
    );
  }
}

/// Stands in for the Kotlin `ActivityRecordingSetupScreen` + recording
/// dashboard, which are a separate port (setup, live dashboard, GPS tabs,
/// splits, focus mode). It exposes the recording controller's start / pause /
/// finish / discard so a recording started here still produces an entry, but it
/// is deliberately not a parity UI.
class _ActivityRecordingPlaceholder extends ConsumerWidget {
  const _ActivityRecordingPlaceholder({
    required this.controller,
    required this.state,
  });

  final ActivityEntryController controller;
  final ActivityEntryUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final recorder = controller.activityRecorder;
    if (recorder == null) return const SizedBox.shrink();

    return ValueListenableBuilder<ActivityRecordingState>(
      valueListenable: recorder.state,
      builder: (context, recording, _) {
        final isActive = recording.isActive;
        final isPaused = recording.status == ActivityRecordingStatus.paused;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(l10n.activityEntryRecordingTitle,
                style: theme.textTheme.titleMedium),
            Text(state.selectedActivityType.label,
                style: theme.textTheme.bodyMedium),
            Text(
              l10n.activityEntryRecordingReadyBody,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            Text(
              '${l10n.activityEntryRecordingDistance}: '
              '${(recording.distanceMeters / 1000).toStringAsFixed(2)} km',
              style: theme.textTheme.bodyMedium,
            ),
            if (recording.errorMessage != null)
              Text(
                recording.errorMessage!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            if (!isActive)
              FilledButton.icon(
                onPressed: controller.startGpsRecording,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.activityEntryRecordGps),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isPaused
                          ? controller.resumeGpsRecording
                          : controller.pauseGpsRecording,
                      child: Text(isPaused
                          ? l10n.activityEntryRecordingActive
                          : l10n.activityEntryRecordingPaused),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => controller
                          .finishGpsRecording(ref.read(unitSystemProvider)),
                      child: Text(l10n.activityEntryRecordingEndSession),
                    ),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: controller.discardGpsRecording,
                child: Text(l10n.actionDiscard),
              ),
            ],
            if (!isActive)
              OutlinedButton.icon(
                onPressed: controller.chooseSource,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(l10n.activityEntryChooseAnotherSource),
              ),
            ActivityEntryErrorText(state: state),
          ],
        );
      },
    );
  }
}
