import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/screen_error.dart';
import '../../di/providers.dart';
import '../../domain/model/body_models.dart';
import '../../domain/preferences/unit_system.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/ov_card.dart';
import '../../ui/theme/app_colors.dart';
import 'body_measurement_entry_notifier.dart';
import 'manual_entry_form_scaffold.dart';
import 'manual_entry_timestamp_fields.dart';

/// Body-measurement manual-entry screen pushed over the shell. Backs the
/// new-entry route (carries [bodyMeasurementType]) and the edit route (also
/// carries [bodyEntryId]).
///
/// Riverpod/Flutter port of the Kotlin `BodyMeasurementEntryScreen`: a value
/// field (metric/imperial aware) writing a `BodyMeasurementWriteRequest`.
class BodyMeasurementEntryScreen extends ConsumerStatefulWidget {
  const BodyMeasurementEntryScreen({
    super.key,
    required this.bodyMeasurementType,
    this.bodyEntryId,
  });

  /// The `BodyMeasurementType` storage name (WEIGHT, HEIGHT, BODY_FAT).
  final String bodyMeasurementType;
  final String? bodyEntryId;

  @override
  ConsumerState<BodyMeasurementEntryScreen> createState() =>
      _BodyMeasurementEntryScreenState();
}

class _BodyMeasurementEntryScreenState
    extends ConsumerState<BodyMeasurementEntryScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _syncedFromState = false;

  late final BodyMeasurementType _type =
      BodyMeasurementType.fromStorage(widget.bodyMeasurementType) ??
          BodyMeasurementType.weight;

  late final NotifierProvider<BodyMeasurementEntryNotifier,
      BodyMeasurementEntryState> _provider = NotifierProvider.autoDispose<
      BodyMeasurementEntryNotifier, BodyMeasurementEntryState>(
    () => BodyMeasurementEntryNotifier(
      _type,
      editRecordId: widget.bodyEntryId,
      imperial: ref.read(unitSystemProvider) == UnitSystem.imperial,
    ),
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
        onManualEntrySaved(context, 'Measurement saved');
      }
    });
    // In edit mode the notifier loads the existing value into the input text;
    // reflect it into the controller once.
    ref.listen(_provider.select((s) => s.inputText), (previous, next) {
      if (!_syncedFromState && next.isNotEmpty && _controller.text != next) {
        _controller.text = next;
        _syncedFromState = true;
      }
    });

    final writePermissions =
        ref.watch(bodyRepositoryProvider).bodyWritePermissions(_type);

    return Scaffold(
      appBar: AppBar(title: Text(_bodyTitle(_type))),
      body: HealthConnectGate(
        requiredPermissions: writePermissions,
        child: _BodyEntryForm(
          type: _type,
          provider: _provider,
          controller: _controller,
        ),
      ),
    );
  }
}

class _BodyEntryForm extends ConsumerWidget {
  const _BodyEntryForm({
    required this.type,
    required this.provider,
    required this.controller,
  });

  final BodyMeasurementType type;
  final NotifierProvider<BodyMeasurementEntryNotifier,
      BodyMeasurementEntryState> provider;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final imperial = ref.watch(unitSystemProvider) == UnitSystem.imperial;
    final title = _bodyTitle(type);
    final unitLabel = _bodyUnitLabel(type, imperial: imperial);
    final enabled =
        state.canWrite && !state.isSavingEntry && !state.isCheckingPermission;

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
                      Icon(_bodyIcon(type),
                          color: _bodyAccent(type), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleSmall),
                            Text(
                              state.canWrite
                                  ? 'Log a $title measurement'
                                  : 'Grant permission to log $title',
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: notifier.updateInput,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '$title ($unitLabel)',
                    ),
                  ),
                  if (state.isEditMode) ...[
                    const SizedBox(height: 12),
                    ManualEntryTimestampFields(
                      timestamp: state.editTime,
                      enabled: !state.isSavingEntry,
                      onChanged: notifier.updateEntryTime,
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: enabled
                        ? () => notifier.addEntry(
                              canonicalBodyMeasurementValue(
                                state.inputText,
                                type,
                                imperial: imperial,
                              ),
                            )
                        : null,
                    icon: Icon(state.isEditMode ? Icons.check : Icons.add,
                        size: 18),
                    label: Text(state.isEditMode ? 'Save' : 'Add $title'),
                  ),
                  if (state.entryError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _errorText(state.entryError!, state.writeError, title),
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

  String _errorText(
    BodyMeasurementEntryError error,
    ScreenError? writeError,
    String title,
  ) {
    switch (error) {
      case BodyMeasurementEntryError.invalidValue:
        return 'Enter a valid $title value.';
      case BodyMeasurementEntryError.missingWritePermission:
        return 'Grant permission to log $title.';
      case BodyMeasurementEntryError.writeFailed:
        return 'Could not save the entry. ${screenErrorText(writeError)}';
    }
  }
}

String _bodyTitle(BodyMeasurementType type) => switch (type) {
      BodyMeasurementType.weight => 'Weight',
      BodyMeasurementType.height => 'Height',
      BodyMeasurementType.bodyFat => 'Body fat',
    };

String _bodyUnitLabel(BodyMeasurementType type, {required bool imperial}) =>
    switch (type) {
      BodyMeasurementType.weight => imperial ? 'lb' : 'kg',
      BodyMeasurementType.height => imperial ? 'in' : 'cm',
      BodyMeasurementType.bodyFat => '%',
    };

IconData _bodyIcon(BodyMeasurementType type) => switch (type) {
      BodyMeasurementType.height => Icons.straighten_outlined,
      _ => Icons.monitor_weight_outlined,
    };

Color _bodyAccent(BodyMeasurementType type) => switch (type) {
      BodyMeasurementType.bodyFat => AppColors.bodyFat,
      _ => AppColors.weight,
    };
