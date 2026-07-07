import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/screen_error.dart';
import '../../di/providers.dart';
import '../../domain/preferences/unit_system.dart';
import '../../navigation/app_routes.dart';
import '../../state/app_providers.dart';
import '../activity/exercise_labels.dart';
import 'activity/activity_entry_clock.dart';
import 'activity/activity_entry_notifier.dart';
import 'activity/activity_entry_providers.dart';
import 'activity/activity_entry_state.dart';
import 'activity/activity_entry_types.dart';
import 'activity/recording/activity_recording.dart';

/// Activity manual-entry / recording screen (Phase 6d). Riverpod + Flutter port
/// of the Kotlin `ActivityEntryScreen` / `ActivityEntryViewModel`. Backs the
/// new-entry route (optional [mode]/[planId]/[activityTypeId] intents) and the
/// edit route ([activityEntryId]).
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

class _ActivityEntryScreenState extends ConsumerState<ActivityEntryScreen> {
  late final ActivityEntryController _controller;

  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _duration = TextEditingController();
  final _distance = TextEditingController();
  final _elevation = TextEditingController();
  final _activeCalories = TextEditingController();
  final _totalCalories = TextEditingController();
  final _repetitionTotal = TextEditingController();

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
    _controller.uiState.addListener(_syncControllers);
    _syncControllers();
    if (widget.activityEntryId != null) {
      _controller.loadEditEntry(ref.read(unitSystemProvider));
    }
  }

  @override
  void dispose() {
    _controller.uiState.removeListener(_syncControllers);
    _controller.dispose();
    for (final c in [
      _title,
      _notes,
      _duration,
      _distance,
      _elevation,
      _activeCalories,
      _totalCalories,
      _repetitionTotal,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    final state = _controller.value;
    _setText(_title, state.titleText);
    _setText(_notes, state.notesText);
    _setText(_duration, state.durationMinutesText);
    _setText(_distance, state.distanceText);
    _setText(_elevation, state.elevationText);
    _setText(_activeCalories, state.activeCaloriesText);
    _setText(_totalCalories, state.totalCaloriesText);
    _setText(_repetitionTotal, state.repetitionTotalText);
    if (state.saveCompleted && mounted) {
      _controller.onSaveCompletedHandled();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActivityEntryUiState>(
      valueListenable: _controller.uiState,
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(state.isEditMode ? 'Edit activity' : 'Add activity'),
          ),
          body: SafeArea(
            child: _buildBody(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ActivityEntryUiState state) {
    switch (state.mode) {
      case ActivityEntryFormMode.chooseSource:
        return _ChooseSource(controller: _controller);
      case ActivityEntryFormMode.planActivityPicker:
        return _PlanActivityPicker(controller: _controller, state: state);
      case ActivityEntryFormMode.planPicker:
        return _PlanPicker(controller: _controller, state: state);
      case ActivityEntryFormMode.recording:
        return _RecordingDashboard(controller: _controller, state: state);
      case ActivityEntryFormMode.manual:
      case ActivityEntryFormMode.routeImport:
        return _buildForm(context, state);
    }
  }

  Widget _buildForm(BuildContext context, ActivityEntryUiState state) {
    final unitSystem = ref.watch(unitSystemProvider);
    final type = state.selectedActivityType;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.entryError != null)
          _ErrorBanner(error: state.entryError!, detail: state.detailError),
        Text('Activity type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in state.activityTypes)
              ChoiceChip(
                label: Text(option.label),
                avatar: Icon(exerciseTypeIcon(option.exerciseType), size: 18),
                selected: option.id == type.id,
                onSelected: (_) => _controller.selectActivityType(option),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title (optional)'),
          onChanged: _controller.updateTitle,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duration (min)'),
                onChanged: _controller.updateDurationMinutes,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateTimeField(
                label: 'Start date',
                value: state.startDateText,
                onTap: () => _pickDate(state),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateTimeField(
                label: 'Start time',
                value: state.startTimeText,
                onTap: () => _pickTime(state),
              ),
            ),
          ],
        ),
        if (type.supportsDistance) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _distance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  'Distance (${unitSystem == UnitSystem.metric ? 'km' : 'mi'})',
            ),
            onChanged: _controller.updateDistance,
          ),
        ],
        if (type.supportsElevation) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _elevation,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  'Elevation gain (${unitSystem == UnitSystem.metric ? 'm' : 'ft'})',
            ),
            onChanged: _controller.updateElevation,
          ),
        ],
        if (type.supportsStepCounting) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _repetitionTotal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Steps (optional)'),
            onChanged: _controller.updateRepetitionTotal,
          ),
        ],
        if (type.supportsSetRepetitions) _buildRepetitions(context, state),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _activeCalories,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Active calories'),
                onChanged: _controller.updateActiveCalories,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _totalCalories,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total calories'),
                onChanged: _controller.updateTotalCalories,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('How did it feel?',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final feeling in ActivityEntryFeeling.values)
              ChoiceChip(
                label: Text('${feeling.emoji} ${feeling.label}'),
                selected: state.selectedFeeling == feeling,
                onSelected: (selected) => _controller
                    .updateFeeling(selected ? feeling : null),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
          onChanged: _controller.updateNotes,
        ),
        if (state.importedRoute != null) ...[
          const SizedBox(height: 16),
          _RouteSummary(state: state, onClear: _controller.clearImportedRoute),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: state.isSavingEntry
              ? null
              : () => _controller.addEntry(ref.read(unitSystemProvider)),
          child: state.isSavingEntry
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(state.isEditMode ? 'Update activity' : 'Save activity'),
        ),
        if (state.isRecordingDraft) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _controller.discardRecordingDraft,
            child: const Text('Discard recording'),
          ),
        ],
      ],
    );
  }

  Widget _buildRepetitions(BuildContext context, ActivityEntryUiState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        SegmentedButton<ActivityRepetitionEntryMode>(
          segments: const [
            ButtonSegment(
                value: ActivityRepetitionEntryMode.total, label: Text('Total')),
            ButtonSegment(
                value: ActivityRepetitionEntryMode.sets, label: Text('Sets')),
          ],
          selected: {state.repetitionMode},
          onSelectionChanged: (selection) =>
              _controller.updateRepetitionMode(selection.first),
        ),
        const SizedBox(height: 8),
        if (state.repetitionMode == ActivityRepetitionEntryMode.total)
          TextField(
            controller: _repetitionTotal,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Repetitions'),
            onChanged: _controller.updateRepetitionTotal,
          )
        else
          Column(
            children: [
              for (var i = 0; i < state.repetitionSets.length; i++)
                _RepetitionSetRow(
                  index: i,
                  input: state.repetitionSets[i],
                  onReps: (text) =>
                      _controller.updateRepetitionSetRepetitions(i, text),
                  onRest: (text) =>
                      _controller.updateRepetitionSetRest(i, text),
                  onRemove: state.repetitionSets.length > 1
                      ? () => _controller.removeRepetitionSet(i)
                      : null,
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _controller.addRepetitionSet,
                  icon: const Icon(Icons.add),
                  label: const Text('Add set'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickDate(ActivityEntryUiState state) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(state.startDateText) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      _controller.updateStartDate(
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _pickTime(ActivityEntryUiState state) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      _controller.updateStartTime(
        '${picked.hour}:${picked.minute.toString().padLeft(2, '0')}',
      );
    }
  }
}

class _ChooseSource extends StatelessWidget {
  const _ChooseSource({required this.controller});

  final ActivityEntryController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SourceCard(
          icon: Icons.gps_fixed,
          title: 'Record with GPS',
          subtitle: 'Track a live run, ride or walk.',
          onTap: controller.prepareGpsRecording,
        ),
        _SourceCard(
          icon: Icons.edit_outlined,
          title: 'Add manually',
          subtitle: 'Log an activity you already finished.',
          onTap: controller.startManualEntry,
        ),
        _SourceCard(
          icon: Icons.event_note_outlined,
          title: 'From a training plan',
          subtitle: 'Complete a planned workout.',
          onTap: controller.startFromExistingPlan,
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _PlanActivityPicker extends StatelessWidget {
  const _PlanActivityPicker({required this.controller, required this.state});

  final ActivityEntryController controller;
  final ActivityEntryUiState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingPlannedWorkouts) {
      return const Center(child: CircularProgressIndicator());
    }
    final typeIds = <String>[];
    for (final plan in state.plannedWorkouts) {
      final type = plannedWorkoutToActivityEntryType(plan);
      if (type != null && !typeIds.contains(type.id)) typeIds.add(type.id);
    }
    if (typeIds.isEmpty) {
      return const Center(child: Text('No matching training plans found.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.entryError != null)
          _ErrorBanner(error: state.entryError!, detail: state.detailError),
        for (final id in typeIds)
          Card(
            child: ListTile(
              title: Text(activityEntryTypeById(id)?.label ?? id),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => controller.selectPlannedWorkoutActivity(id),
            ),
          ),
      ],
    );
  }
}

class _PlanPicker extends StatelessWidget {
  const _PlanPicker({required this.controller, required this.state});

  final ActivityEntryController controller;
  final ActivityEntryUiState state;

  @override
  Widget build(BuildContext context) {
    final typeId = state.selectedPlannedWorkoutActivityTypeId;
    final plans = state.plannedWorkouts
        .where((plan) => plannedWorkoutToActivityEntryType(plan)?.id == typeId)
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final plan in plans)
          Card(
            child: ListTile(
              title: Text(plan.title ?? 'Planned workout'),
              subtitle: plan.notes == null ? null : Text(plan.notes!),
              onTap: () => controller.applyPlannedWorkout(plan.id),
            ),
          ),
        TextButton(
          onPressed: controller.choosePlannedWorkoutActivity,
          child: const Text('Back to activity types'),
        ),
      ],
    );
  }
}

class _RecordingDashboard extends StatelessWidget {
  const _RecordingDashboard({required this.controller, required this.state});

  final ActivityEntryController controller;
  final ActivityEntryUiState state;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActivityRecordingState>(
      valueListenable:
          controller.activityRecorder?.state ?? _idleRecording,
      builder: (context, recording, _) {
        final isActive = recording.isActive;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                state.selectedActivityType.label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Status: ${recording.status.name}'),
              Text(
                'Distance: '
                '${(recording.distanceMeters / 1000).toStringAsFixed(2)} km',
              ),
              if (recording.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(recording.errorMessage!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ],
              const Spacer(),
              if (!isActive)
                FilledButton.icon(
                  onPressed: () => controller.startGpsRecording(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            recording.status == ActivityRecordingStatus.paused
                                ? controller.resumeGpsRecording
                                : controller.pauseGpsRecording,
                        child: Text(
                          recording.status == ActivityRecordingStatus.paused
                              ? 'Resume'
                              : 'Pause',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            controller.finishGpsRecording(_unitSystemOf(context)),
                        child: const Text('Finish'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: controller.discardGpsRecording,
                  child: const Text('Discard'),
                ),
              ],
              if (!isActive)
                TextButton(
                  onPressed: controller.chooseSource,
                  child: const Text('Back'),
                ),
            ],
          ),
        );
      },
    );
  }

  UnitSystem _unitSystemOf(BuildContext context) =>
      ProviderScope.containerOf(context).read(unitSystemProvider);
}

final ValueNotifier<ActivityRecordingState> _idleRecording =
    ValueNotifier(const ActivityRecordingState());

class _RepetitionSetRow extends StatelessWidget {
  const _RepetitionSetRow({
    required this.index,
    required this.input,
    required this.onReps,
    required this.onRest,
    required this.onRemove,
  });

  final int index;
  final ActivityRepetitionSetInput input;
  final ValueChanged<String> onReps;
  final ValueChanged<String> onRest;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('${index + 1}.')),
          Expanded(
            child: TextField(
              key: ValueKey('reps-$index-${input.repetitionsText}'),
              controller: TextEditingController(text: input.repetitionsText)
                ..selection = TextSelection.collapsed(
                    offset: input.repetitionsText.length),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
              onChanged: onReps,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: ValueKey('rest-$index-${input.restMinutesText}'),
              controller: TextEditingController(text: input.restMinutesText)
                ..selection = TextSelection.collapsed(
                    offset: input.restMinutesText.length),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Rest (s)'),
              onChanged: onRest,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.state, required this.onClear});

  final ActivityEntryUiState state;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final route = state.importedRoute!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    route.name ?? route.fileName ?? 'Imported route',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${route.points.length} points · '
                '${(route.distanceMeters / 1000).toStringAsFixed(2)} km'),
            // TODO(phase6-maps): render the route on a map (Phase 6e). This
            // batch shows a point/summary list rather than a map.
          ],
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value.isEmpty ? '—' : value),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, this.detail});

  final ActivityEntryError error;
  final ScreenError? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _message(),
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }

  String _message() {
    final detailText =
        detail is ScreenErrorMessage ? (detail as ScreenErrorMessage).text : null;
    switch (error) {
      case ActivityEntryError.invalidValue:
        return 'Please check the highlighted fields.';
      case ActivityEntryError.missingWritePermission:
        return 'Health Connect write permission is required.';
      case ActivityEntryError.routeImportFailed:
        return 'Route import failed. ${detailText ?? ''}'.trim();
      case ActivityEntryError.locationPermissionNeeded:
        return 'Location permission is needed to record.';
      case ActivityEntryError.notificationPermissionNeeded:
        return 'Notification permission is needed to record.';
      case ActivityEntryError.activityRecognitionPermissionNeeded:
        return 'Activity recognition permission is needed to record.';
      case ActivityEntryError.recordingFailed:
        return 'Recording failed. ${detailText ?? ''}'.trim();
      case ActivityEntryError.writeFailed:
        return 'Saving failed. ${detailText ?? ''}'.trim();
    }
  }
}
