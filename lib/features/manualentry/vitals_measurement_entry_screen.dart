import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/screen_error.dart';
import '../../di/providers.dart';
import '../../domain/model/vitals_models.dart';
import '../../domain/preferences/unit_system.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/ov_card.dart';
import '../../ui/theme/app_colors.dart';
import 'manual_entry_form_scaffold.dart';
import 'manual_entry_timestamp_fields.dart';
import 'vitals_measurement_entry_notifier.dart';

const Color _oxygenColor = Color(0xFF00897B);
const Color _respiratoryColor = Color(0xFF5E97F6);
const Color _temperatureColor = Color(0xFFFF7043);

/// Vitals-measurement manual-entry screen pushed over the shell. Backs the
/// new-entry route (carries [vitalsMeasurementType]) and the edit route (also
/// carries [vitalsEntryId]).
///
/// Riverpod/Flutter port of the Kotlin `VitalsMeasurementEntryScreen`: single
/// value field (systolic + diastolic for blood pressure) writing a
/// `VitalsMeasurementWriteRequest`.
class VitalsMeasurementEntryScreen extends ConsumerStatefulWidget {
  const VitalsMeasurementEntryScreen({
    super.key,
    required this.vitalsMeasurementType,
    this.vitalsEntryId,
  });

  /// The `VitalsMeasurementType` storage name (BLOOD_PRESSURE, SPO2, …).
  final String vitalsMeasurementType;
  final String? vitalsEntryId;

  @override
  ConsumerState<VitalsMeasurementEntryScreen> createState() =>
      _VitalsMeasurementEntryScreenState();
}

class _VitalsMeasurementEntryScreenState
    extends ConsumerState<VitalsMeasurementEntryScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _secondaryController = TextEditingController();
  bool _syncedFromState = false;

  late final VitalsMeasurementType _type =
      VitalsMeasurementType.fromStorage(widget.vitalsMeasurementType) ??
          VitalsMeasurementType.bloodPressure;

  late final NotifierProvider<VitalsMeasurementEntryNotifier,
      VitalsMeasurementEntryState> _provider = NotifierProvider.autoDispose<
      VitalsMeasurementEntryNotifier, VitalsMeasurementEntryState>(
    () => VitalsMeasurementEntryNotifier(
      _type,
      editRecordId: widget.vitalsEntryId,
      imperial: ref.read(unitSystemProvider) == UnitSystem.imperial,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    _secondaryController.dispose();
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
    ref.listen(_provider, (previous, next) {
      if (!_syncedFromState &&
          (next.inputText.isNotEmpty || next.secondaryInputText.isNotEmpty)) {
        if (_controller.text != next.inputText) {
          _controller.text = next.inputText;
        }
        if (_secondaryController.text != next.secondaryInputText) {
          _secondaryController.text = next.secondaryInputText;
        }
        _syncedFromState = true;
      }
    });

    final writePermissions =
        ref.watch(vitalsRepositoryProvider).vitalsWritePermissions(_type);

    return Scaffold(
      appBar: AppBar(title: Text(_vitalsTitle(_type))),
      body: HealthConnectGate(
        requiredPermissions: writePermissions,
        child: _VitalsEntryForm(
          type: _type,
          provider: _provider,
          controller: _controller,
          secondaryController: _secondaryController,
        ),
      ),
    );
  }
}

class _VitalsEntryForm extends ConsumerWidget {
  const _VitalsEntryForm({
    required this.type,
    required this.provider,
    required this.controller,
    required this.secondaryController,
  });

  final VitalsMeasurementType type;
  final NotifierProvider<VitalsMeasurementEntryNotifier,
      VitalsMeasurementEntryState> provider;
  final TextEditingController controller;
  final TextEditingController secondaryController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final imperial = ref.watch(unitSystemProvider) == UnitSystem.imperial;
    final title = _vitalsTitle(type);
    final unitLabel = _vitalsUnitLabel(type, imperial: imperial);
    final isBloodPressure = type == VitalsMeasurementType.bloodPressure;
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
                      Icon(_vitalsIcon(type),
                          color: _vitalsAccent(type), size: 22),
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
                  if (isBloodPressure)
                    Row(
                      children: [
                        Expanded(
                          child: _valueField(
                            controller: controller,
                            label: 'Systolic',
                            enabled: !state.isSavingEntry,
                            onChanged: notifier.updateInput,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _valueField(
                            controller: secondaryController,
                            label: 'Diastolic',
                            enabled: !state.isSavingEntry,
                            onChanged: notifier.updateSecondaryInput,
                          ),
                        ),
                      ],
                    )
                  else
                    _valueField(
                      controller: controller,
                      label: '$title ($unitLabel)',
                      enabled: !state.isSavingEntry,
                      onChanged: notifier.updateInput,
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
                              canonicalVitalsValue(
                                state.inputText,
                                type,
                                imperial: imperial,
                              ),
                              secondaryValue: isBloodPressure
                                  ? parseVitalsDouble(state.secondaryInputText)
                                  : null,
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

  Widget _valueField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) =>
      TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      );

  String _errorText(
    VitalsMeasurementEntryError error,
    ScreenError? writeError,
    String title,
  ) {
    switch (error) {
      case VitalsMeasurementEntryError.invalidValue:
        return 'Enter a valid $title value.';
      case VitalsMeasurementEntryError.missingWritePermission:
        return 'Grant permission to log $title.';
      case VitalsMeasurementEntryError.writeFailed:
        return 'Could not save the entry. ${screenErrorText(writeError)}';
    }
  }
}

String _vitalsTitle(VitalsMeasurementType type) => switch (type) {
      VitalsMeasurementType.bloodPressure => 'Blood pressure',
      VitalsMeasurementType.spo2 => 'Blood oxygen',
      VitalsMeasurementType.respiratoryRate => 'Respiratory rate',
      VitalsMeasurementType.bodyTemperature => 'Body temperature',
    };

String _vitalsUnitLabel(VitalsMeasurementType type, {required bool imperial}) =>
    switch (type) {
      VitalsMeasurementType.bloodPressure => 'mmHg',
      VitalsMeasurementType.spo2 => '%',
      VitalsMeasurementType.respiratoryRate => 'br/min',
      VitalsMeasurementType.bodyTemperature => imperial ? 'deg F' : 'deg C',
    };

IconData _vitalsIcon(VitalsMeasurementType type) => switch (type) {
      VitalsMeasurementType.bloodPressure => Icons.favorite,
      VitalsMeasurementType.spo2 => Icons.favorite_border,
      VitalsMeasurementType.respiratoryRate => Icons.air,
      VitalsMeasurementType.bodyTemperature => Icons.device_thermostat,
    };

Color _vitalsAccent(VitalsMeasurementType type) => switch (type) {
      VitalsMeasurementType.bloodPressure => AppColors.vitals,
      VitalsMeasurementType.spo2 => _oxygenColor,
      VitalsMeasurementType.respiratoryRate => _respiratoryColor,
      VitalsMeasurementType.bodyTemperature => _temperatureColor,
    };
