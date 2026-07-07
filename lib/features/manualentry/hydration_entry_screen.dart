import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/screen_error.dart';
import '../../di/providers.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/ov_card.dart';
import '../../ui/theme/app_colors.dart';
import 'hydration_entry_notifier.dart';
import 'manual_entry_form_scaffold.dart';
import 'manual_entry_timestamp_fields.dart';

/// Hydration manual-entry screen pushed over the shell. Backs three routes:
/// new entry, edit (carries [hydrationEntryId]) and log-drink (carries
/// [logDrinkId], which pre-selects a saved custom drink).
///
/// Riverpod/Flutter port of the Kotlin `HydrationEntryScreen`: container presets,
/// a custom amount field and saved-drink logging writing `HydrationWriteRequest`
/// (plus an associated `NutritionWriteRequest` for drinks that carry nutrients).
class HydrationEntryScreen extends ConsumerStatefulWidget {
  const HydrationEntryScreen({
    super.key,
    this.hydrationEntryId,
    this.logDrinkId,
  });

  final String? hydrationEntryId;
  final String? logDrinkId;

  @override
  ConsumerState<HydrationEntryScreen> createState() =>
      _HydrationEntryScreenState();
}

class _HydrationEntryScreenState extends ConsumerState<HydrationEntryScreen> {
  final TextEditingController _customController = TextEditingController();

  late final NotifierProvider<HydrationEntryNotifier, HydrationEntryState>
      _provider = NotifierProvider.autoDispose<HydrationEntryNotifier,
          HydrationEntryState>(
    () => HydrationEntryNotifier(editRecordId: widget.hydrationEntryId),
  );

  @override
  void initState() {
    super.initState();
    final last = ref.read(_provider).lastCustomAmountMilliliters;
    if (last != null) {
      _customController.text = _trim(last);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(_provider.select((s) => s.saveCompleted), (previous, next) {
      if (next) {
        ref.read(_provider.notifier).onSaveCompletedHandled();
        onManualEntrySaved(context, 'Hydration entry saved');
      }
    });

    final writePermissions =
        ref.watch(hydrationRepositoryProvider).hydrationWritePermissions;

    return Scaffold(
      appBar: AppBar(title: const Text('Hydration entry')),
      body: HealthConnectGate(
        requiredPermissions: writePermissions,
        child: _HydrationEntryForm(
          provider: _provider,
          customController: _customController,
        ),
      ),
    );
  }
}

class _HydrationEntryForm extends ConsumerWidget {
  const _HydrationEntryForm({
    required this.provider,
    required this.customController,
  });

  final NotifierProvider<HydrationEntryNotifier, HydrationEntryState> provider;
  final TextEditingController customController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final formatter = ref.watch(unitFormatterProvider);
    final enabled = state.canWriteHydration &&
        !state.isSavingEntry &&
        !state.isCheckingPermission;

    final today = formatter.hydration(state.todayHydrationLiters);
    final goal = formatter.hydration(state.dailyGoalLiters);

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
                      const Icon(Icons.local_drink_outlined,
                          color: AppColors.hydration, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hydration',
                                style: theme.textTheme.titleSmall),
                            Text(
                              'Today ${today.value} ${today.unit} '
                              '/ ${goal.value} ${goal.unit}',
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
                  Text('Containers', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in state.containerOptions)
                        ChoiceChip(
                          label: Text(_containerLabel(option)),
                          selected: option.id == state.selectedContainer.id,
                          onSelected: state.isSavingEntry
                              ? null
                              : (_) => notifier.selectContainer(option),
                        ),
                    ],
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
                    onPressed:
                        enabled ? notifier.addSelectedHydrationEntry : null,
                    icon: Icon(state.isEditMode ? Icons.check : Icons.add,
                        size: 18),
                    label: Text(
                      state.isEditMode
                          ? 'Save'
                          : 'Add ${_containerLabel(state.selectedContainer)}',
                    ),
                  ),
                  if (!state.isEditMode) ...[
                    const Divider(height: 32),
                    Text('Custom amount', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customController,
                            enabled: !state.isSavingEntry,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Amount (mL)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: enabled
                              ? () {
                                  final ml = double.tryParse(
                                    customController.text
                                        .trim()
                                        .replaceAll(',', '.'),
                                  );
                                  notifier.addCustomHydrationEntry(ml ?? -1);
                                }
                              : null,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                  if (state.customDrinkOptions.isNotEmpty &&
                      !state.isEditMode) ...[
                    const Divider(height: 32),
                    Text('Saved drinks', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    for (final drink in state.customDrinkOptions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: enabled
                              ? () => notifier.addSavedCustomDrinkEntry(drink)
                              : null,
                          icon: const Icon(Icons.add, size: 18),
                          label: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${drink.name} · '
                              '${_trim(drink.volumeMilliliters)} mL',
                            ),
                          ),
                        ),
                      ),
                  ],
                  if (state.entryNotice ==
                      HydrationEntryNotice.nonHydratingDrinkSaved)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Saved nutrients for a non-hydrating drink.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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

  String _containerLabel(HydrationContainerOption option) {
    final ml = option.volumeMilliliters;
    if (ml >= kMillilitersPerLiter) {
      return '${_trim(ml / kMillilitersPerLiter)} L';
    }
    return '${_trim(ml)} mL';
  }

  String _errorText(HydrationEntryError error, ScreenError? writeError) {
    switch (error) {
      case HydrationEntryError.invalidAmount:
        return 'Enter a valid amount.';
      case HydrationEntryError.invalidCustomDrink:
        return 'This drink is not valid.';
      case HydrationEntryError.missingWritePermission:
        return 'Grant permission to log hydration.';
      case HydrationEntryError.missingNutritionWritePermission:
        return 'Grant permission to log nutrition.';
      case HydrationEntryError.writeFailed:
        return 'Could not save the entry. ${screenErrorText(writeError)}';
    }
  }
}

/// Formats a double as a compact string (trailing zeros trimmed).
String _trim(double value) {
  var text = value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return text;
}
