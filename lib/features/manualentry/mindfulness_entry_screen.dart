import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/screen_error.dart';
import '../../di/providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/ov_card.dart';
import '../../ui/theme/app_colors.dart';
import 'manual_entry_form_scaffold.dart';
import 'manual_entry_timestamp_fields.dart';
import 'mindfulness_entry_notifier.dart';

/// Mindfulness manual-entry screen pushed over the shell. Handles both the
/// new-entry route and the edit route (which carries a [mindfulnessEntryId]).
///
/// Riverpod/Flutter port of the Kotlin `MindfulnessEntryScreen`, MANUAL duration
/// path only: a minutes field writing a `MindfulnessSessionWriteRequest`. The
/// live meditation timer + bell/ambient sound is a later batch.
// TODO(phase6d): add the live timer + bell/background-sound UI.
class MindfulnessEntryScreen extends ConsumerStatefulWidget {
  const MindfulnessEntryScreen({super.key, this.mindfulnessEntryId});

  final String? mindfulnessEntryId;

  @override
  ConsumerState<MindfulnessEntryScreen> createState() =>
      _MindfulnessEntryScreenState();
}

class _MindfulnessEntryScreenState
    extends ConsumerState<MindfulnessEntryScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _syncedFromState = false;

  late final NotifierProvider<MindfulnessEntryNotifier, MindfulnessEntryState>
      _provider =
      NotifierProvider.autoDispose<MindfulnessEntryNotifier,
          MindfulnessEntryState>(
    () => MindfulnessEntryNotifier(editRecordId: widget.mindfulnessEntryId),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_provider.select((s) => s.saveCompleted), (previous, next) {
      if (next) {
        ref.read(_provider.notifier).onSaveCompletedHandled();
        onManualEntrySaved(context, 'Mindfulness session saved');
      }
    });
    ref.listen(_provider.select((s) => s.manualMinutesText), (previous, next) {
      if (!_syncedFromState && next.isNotEmpty && _controller.text != next) {
        _controller.text = next;
        _syncedFromState = true;
      }
    });

    final writePermissions =
        ref.watch(mindfulnessRepositoryProvider).mindfulnessWritePermissions;

    return Scaffold(
      appBar: AppBar(title: const Text('Mindfulness')),
      body: HealthConnectGate(
        requiredPermissions: writePermissions,
        child:
            _MindfulnessEntryForm(provider: _provider, controller: _controller),
      ),
    );
  }
}

class _MindfulnessEntryForm extends ConsumerWidget {
  const _MindfulnessEntryForm({
    required this.provider,
    required this.controller,
  });

  final NotifierProvider<MindfulnessEntryNotifier, MindfulnessEntryState>
      provider;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final enabled = state.canWrite &&
        state.mindfulnessAvailable &&
        !state.isSavingEntry &&
        !state.isCheckingPermission;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: OpenVitalsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.self_improvement,
                          color: AppColors.mindfulness, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mindfulness',
                                style: theme.textTheme.titleSmall),
                            Text(
                              state.canWrite
                                  ? 'Log a completed session by duration'
                                  : 'Grant permission to log sessions',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    enabled: !state.isSavingEntry,
                    keyboardType: TextInputType.number,
                    onChanged: notifier.updateManualMinutes,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Duration (minutes)',
                    ),
                  ),
                  if (state.isEditMode) ...[
                    const SizedBox(height: 12),
                    ManualEntryTimestampFields(
                      timestamp: state.editStartTime,
                      enabled: !state.isSavingEntry,
                      onChanged: notifier.updateEntryStartTime,
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: enabled ? notifier.addManualEntry : null,
                    icon: Icon(state.isEditMode ? Icons.check : Icons.add,
                        size: 18),
                    label: Text(state.isEditMode ? 'Save' : 'Log session'),
                  ),
                  if (state.entryError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _errorText(state.entryError!, state.writeError),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _errorText(MindfulnessEntryError error, ScreenError? writeError) {
    switch (error) {
      case MindfulnessEntryError.invalidManualEntry:
        return 'Enter a duration between 1 and 1440 minutes.';
      case MindfulnessEntryError.missingWritePermission:
        return 'Grant permission to log sessions.';
      case MindfulnessEntryError.unavailable:
        return 'Mindfulness is not available on this device.';
      case MindfulnessEntryError.writeFailed:
        return 'Could not save the session. ${screenErrorText(writeError)}';
    }
  }
}
