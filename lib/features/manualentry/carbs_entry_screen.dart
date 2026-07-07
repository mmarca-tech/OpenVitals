import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/screen_error.dart';
import '../../di/providers.dart';
import '../../domain/preferences/unit_system.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/ov_card.dart';
import '../../ui/theme/app_colors.dart';
import 'carbs_entry_notifier.dart';
import 'manual_entry_form_scaffold.dart';

/// Carbs manual-entry screen pushed over the shell (`/manual_entry/carbs`).
///
/// Riverpod/Flutter port of the Kotlin `CarbsEntryScreen`: a single value field
/// writing a `NutritionWriteRequest` via `NutritionRepository.writeCarbsEntry`.
class CarbsEntryScreen extends ConsumerStatefulWidget {
  const CarbsEntryScreen({super.key});

  @override
  ConsumerState<CarbsEntryScreen> createState() => _CarbsEntryScreenState();
}

class _CarbsEntryScreenState extends ConsumerState<CarbsEntryScreen> {
  late final NotifierProvider<CarbsEntryNotifier, CarbsEntryState> _provider =
      NotifierProvider.autoDispose<CarbsEntryNotifier, CarbsEntryState>(
    CarbsEntryNotifier.new,
  );

  final TextEditingController _controller = TextEditingController();

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
        onManualEntrySaved(context, 'Carbs entry saved');
      }
    });

    final writePermissions =
        ref.watch(nutritionRepositoryProvider).nutritionWritePermissions;

    return Scaffold(
      appBar: AppBar(title: const Text('Carbs entry')),
      body: HealthConnectGate(
        requiredPermissions: writePermissions,
        child: _CarbsEntryForm(provider: _provider, controller: _controller),
      ),
    );
  }
}

class _CarbsEntryForm extends ConsumerWidget {
  const _CarbsEntryForm({required this.provider, required this.controller});

  final NotifierProvider<CarbsEntryNotifier, CarbsEntryState> provider;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final imperial = ref.watch(unitSystemProvider) == UnitSystem.imperial;
    final unitLabel = imperial ? 'oz' : 'g';
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
                      const Icon(Icons.restaurant_outlined,
                          color: AppColors.nutrition, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Carbs', style: theme.textTheme.titleSmall),
                            Text(
                              state.canWrite
                                  ? 'Log a carbohydrate amount'
                                  : 'Grant permission to log carbs',
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
                      labelText: 'Carbs ($unitLabel)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: enabled
                        ? () => notifier.addEntry(
                              canonicalCarbsGrams(
                                state.inputText,
                                imperial: imperial,
                              ),
                            )
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add carbs'),
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

  String _errorText(CarbsEntryError error, ScreenError? writeError) {
    switch (error) {
      case CarbsEntryError.invalidValue:
        return 'Enter a valid carbs amount.';
      case CarbsEntryError.missingWritePermission:
        return 'Grant permission to log carbs.';
      case CarbsEntryError.writeFailed:
        return 'Could not save the entry. ${screenErrorText(writeError)}';
    }
  }
}
