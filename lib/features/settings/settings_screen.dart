import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/components/metric_card.dart';
import '../../ui/components/ov_card.dart';
import 'settings_section.dart';

/// Settings nav-suite branch body (rendered inside the adaptive scaffold), ported
/// from the Kotlin `SettingsScreen` root (`settingsScreenContent(section = null)`).
/// Lists the settings sections plus a privacy footer.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final section in SettingsSection.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _SettingsCategoryCard(section: section),
              ),
            SectionHeader(l10n.sectionPrivacy),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: OpenVitalsCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsPrivacyOnDevice,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.privacyPolicyBody2,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Text(
                l10n.appName,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCategoryCard extends StatelessWidget {
  const _SettingsCategoryCard({required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return OpenVitalsCard(
      onTap: () => context.push(section.route),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(section.icon, color: theme.colorScheme.onSurface, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.localizedTitle(l10n),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    section.localizedSummary(l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
