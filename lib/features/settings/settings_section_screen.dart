import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/providers.dart';
import '../../domain/model/health_connect_availability.dart';
import '../../domain/preferences/activity_week_mode.dart';
import '../../domain/preferences/app_language.dart';
import '../../domain/preferences/app_theme_mode.dart';
import '../../domain/preferences/sleep_range_mode.dart';
import '../../domain/preferences/unit_system.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/ov_card.dart';
import '../../ui/components/placeholder_screen.dart';
import 'settings_notifier.dart';
import 'settings_section.dart';

/// A settings sub-section pushed over the shell, ported from the Kotlin
/// `settingsScreenContent(section = ...)`. Renders the cards for [section] and
/// wires each control to [settingsProvider] (which persists through
/// `PreferencesRepository`).
///
/// The BLE Sensors and Data Import sections configure Phase-6 subsystems and
/// route to a "coming soon" placeholder.
class SettingsSectionScreen extends ConsumerWidget {
  const SettingsSectionScreen({super.key, required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      body: switch (section) {
        SettingsSection.sensors => const _ComingSoonBody(
            // TODO(phase6): BLE heart-rate sensor pairing is a Phase-6 subsystem.
            message: 'Bluetooth sensor pairing is coming in a later update.',
          ),
        SettingsSection.dataImport => const _ComingSoonBody(
            // TODO(phase6): Apple Health / .fit import is a Phase-6 subsystem.
            message: 'Apple Health and .fit import are coming in a later update.',
          ),
        _ => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _cards(context, ref, section),
              ),
            ),
          ),
      },
    );
  }
}

List<Widget> _cards(BuildContext context, WidgetRef ref, SettingsSection section) {
  final notifier = ref.read(settingsProvider.notifier);
  final state = ref.watch(settingsProvider);
  switch (section) {
    case SettingsSection.display:
      return [
        _SettingsCard(
          title: 'Language',
          body: 'Choose the app language.',
          child: _LanguageDropdown(
            selected: state.appLanguage,
            onSelect: notifier.selectAppLanguage,
          ),
        ),
        _SettingsCard(
          title: 'Units',
          body: 'Distance, weight and temperature units.',
          child: _ChoiceRow<UnitSystem>(
            options: UnitSystem.values,
            selected: state.unitSystem,
            labelFor: _unitLabel,
            onSelect: notifier.selectUnitSystem,
          ),
        ),
        _SettingsCard(
          title: 'Theme',
          body: 'Light, dark or system appearance.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChoiceRow<AppThemeMode>(
                options: AppThemeMode.values,
                selected: state.appThemeMode,
                labelFor: _themeLabel,
                onSelect: notifier.selectAppThemeMode,
              ),
              const SizedBox(height: 8),
              _InlineSwitchRow(
                title: 'Dynamic colour',
                body: 'Use colours from your wallpaper.',
                value: state.dynamicColor,
                onChanged: notifier.setDynamicColor,
              ),
            ],
          ),
        ),
      ];
    case SettingsSection.activities:
      return [
        _SettingsCard(
          title: 'Week layout',
          body: 'How the weekly period is defined.',
          child: _ChoiceRow<ActivityWeekMode>(
            options: ActivityWeekMode.values,
            selected: state.activityWeekMode,
            labelFor: _weekLabel,
            onSelect: notifier.selectActivityWeekMode,
          ),
        ),
      ];
    case SettingsSection.nutrition:
      final formatter = ref.watch(unitFormatterProvider);
      return [
        _SwitchCard(
          title: 'Show calculated calories',
          body: 'Display OpenVitals-estimated calories when no data exists.',
          value: state.showOpenVitalsCalculatedCalories,
          onChanged: notifier.setShowOpenVitalsCalculatedCalories,
        ),
        _StepperCard(
          title: 'Hydration goal',
          body: 'Your daily hydration target.',
          valueLabel: formatter.hydration(state.hydrationDailyGoalLiters).text,
          onDecrement: () => notifier.setHydrationDailyGoalLiters(
            state.hydrationDailyGoalLiters - 0.25,
          ),
          onIncrement: () => notifier.setHydrationDailyGoalLiters(
            state.hydrationDailyGoalLiters + 0.25,
          ),
        ),
        const _StubEntryCard(
          title: 'Caffeine preferences',
          // TODO(phase6): the caffeine profile editor lands in Phase 6.
          body: 'Caffeine metabolism settings are coming in a later update.',
        ),
      ];
    case SettingsSection.recovery:
      return [
        _SettingsCard(
          title: 'Sleep window',
          body: 'Which day a sleep session is attributed to.',
          child: _ChoiceRow<SleepRangeMode>(
            options: SleepRangeMode.values,
            selected: state.sleepRangeMode,
            labelFor: _sleepLabel,
            onSelect: notifier.selectSleepRangeMode,
          ),
        ),
        _StepperCard(
          title: 'High heart-rate alert',
          body: 'Threshold for a high resting heart-rate flag.',
          valueLabel: '${state.highHeartRateThresholdBpm} bpm',
          onDecrement: () => notifier.setHighHeartRateThresholdBpm(
            state.highHeartRateThresholdBpm - 5,
          ),
          onIncrement: () => notifier.setHighHeartRateThresholdBpm(
            state.highHeartRateThresholdBpm + 5,
          ),
        ),
        _StepperCard(
          title: 'Low heart-rate alert',
          body: 'Threshold for a low resting heart-rate flag.',
          valueLabel: '${state.lowHeartRateThresholdBpm} bpm',
          onDecrement: () => notifier.setLowHeartRateThresholdBpm(
            state.lowHeartRateThresholdBpm - 5,
          ),
          onIncrement: () => notifier.setLowHeartRateThresholdBpm(
            state.lowHeartRateThresholdBpm + 5,
          ),
        ),
        const _StubEntryCard(
          title: 'Body energy calibration',
          // TODO(phase6): the manual heart-zone calibration editor lands in Phase 6.
          body: 'Manual heart-zone calibration is coming in a later update.',
        ),
      ];
    case SettingsSection.healthConnect:
      return [
        _SwitchCard(
          title: 'Health Connect sync',
          body: 'Read and write health data through Health Connect.',
          value: state.healthConnectSyncEnabled,
          onChanged: notifier.setHealthConnectSyncEnabled,
        ),
        _SwitchCard(
          title: 'App lock',
          body: 'Require device authentication to open OpenVitals.',
          value: state.appLockEnabled,
          onChanged: notifier.setAppLockEnabled,
        ),
        const _PermissionsCard(),
      ];
    case SettingsSection.sensors:
    case SettingsSection.dataImport:
      return const [];
  }
}

String _unitLabel(UnitSystem value) => switch (value) {
      UnitSystem.metric => 'Metric',
      UnitSystem.imperial => 'Imperial',
    };

String _themeLabel(AppThemeMode value) => switch (value) {
      AppThemeMode.system => 'System',
      AppThemeMode.light => 'Light',
      AppThemeMode.dark => 'Dark',
      AppThemeMode.amoled => 'AMOLED',
    };

String _sleepLabel(SleepRangeMode value) => switch (value) {
      SleepRangeMode.rolling24h => 'Rolling 24h',
      SleepRangeMode.noon => 'Noon',
      SleepRangeMode.evening18h => 'Evening',
    };

String _weekLabel(ActivityWeekMode value) => switch (value) {
      ActivityWeekMode.mondayToSunday => 'Mon–Sun',
      ActivityWeekMode.last7Days => 'Last 7 days',
    };

String _languageLabel(AppLanguage value) => switch (value) {
      AppLanguage.system => 'System default',
      AppLanguage.english => 'English',
      AppLanguage.spanish => 'Español',
      AppLanguage.german => 'Deutsch',
      AppLanguage.italian => 'Italiano',
      AppLanguage.estonian => 'Eesti',
    };

/// A titled card wrapping a settings control. Port of the Kotlin settings card
/// chrome (title + body + control).
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.body,
    required this.child,
  });

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OpenVitalsCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// A single-choice chip row. A trimmed port of the Kotlin
/// `SingleChoiceSegmentedButtonRow`.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onSelect,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(labelFor(option)),
            selected: option == selected,
            onSelected: (_) => onSelect(option),
          ),
      ],
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({required this.selected, required this.onSelect});

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelect;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: selected,
          isExpanded: true,
          items: [
            for (final language in AppLanguage.values)
              DropdownMenuItem(
                value: language,
                child: Text(_languageLabel(language)),
              ),
          ],
          onChanged: (value) {
            if (value != null) onSelect(value);
          },
        ),
      ),
    );
  }
}

/// A card whose whole body is a switch row.
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OpenVitalsCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _InlineSwitchRow(
            title: title,
            body: body,
            value: value,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _InlineSwitchRow extends StatelessWidget {
  const _InlineSwitchRow({
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// A -/+ stepper card for numeric settings (hydration goal, HR thresholds).
class _StepperCard extends StatelessWidget {
  const _StepperCard({
    required this.title,
    required this.body,
    required this.valueLabel,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String title;
  final String body;
  final String valueLabel;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OpenVitalsCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Decrease',
              ),
              SizedBox(
                width: 88,
                child: Text(
                  valueLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Increase',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card that names a Phase-6 settings entry that is not yet available.
class _StubEntryCard extends StatelessWidget {
  const _StubEntryCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OpenVitalsCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Health Connect permission summary + grant action. Reads the availability
/// and granted-permission providers. A trimmed port of the Kotlin
/// `PermissionCategoryCard` list.
class _PermissionsCard extends ConsumerWidget {
  const _PermissionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final availability = ref.watch(healthConnectAvailabilityProvider).value;
    final granted = ref.watch(grantedHealthPermissionsProvider).value;
    final all = ref.watch(healthRepositoryProvider).allPermissions;

    final String body;
    Widget? action;
    if (availability == null || granted == null) {
      body = 'Checking Health Connect access…';
    } else if (availability != HealthConnectAvailability.available) {
      body = 'Health Connect is not available on this device.';
    } else {
      final grantedCount = all.where(granted.contains).length;
      final missing = all.difference(granted);
      body = '$grantedCount of ${all.length} permissions granted.';
      if (missing.isNotEmpty) {
        action = Padding(
          padding: const EdgeInsets.only(top: 12),
          child: FilledButton.tonal(
            onPressed: () async {
              await ref
                  .read(healthRepositoryProvider)
                  .requestPermissions(missing);
              ref.invalidate(grantedHealthPermissionsProvider);
            },
            child: const Text('Manage permissions'),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OpenVitalsCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Permissions', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonBody extends StatelessWidget {
  const _ComingSoonBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) =>
      PlaceholderBody(title: message);
}
