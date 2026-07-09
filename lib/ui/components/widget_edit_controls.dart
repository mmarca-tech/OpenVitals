import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// The ✕ overlaid on a customizable widget in edit mode, which removes it from
/// the screen. Port of the Kotlin `onRemove` affordance; shared by the dashboard
/// summary and the add-entry hub.
class RemoveWidgetButton extends StatelessWidget {
  const RemoveWidgetButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      tooltip: AppLocalizations.of(context).cdRemoveWidget,
      onPressed: onPressed,
      icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
    );
  }
}

/// The edit-mode "Add widgets" tray: every widget the user has removed, as a
/// tap-to-restore row. Port of the Kotlin `DashboardHiddenWidgets` /
/// `hiddenManualEntryWidgets`.
///
/// [titles] must already exclude widgets the device cannot support — those can
/// never be restored, so offering them would be a dead end.
class HiddenWidgetsSection extends StatelessWidget {
  const HiddenWidgetsSection({
    super.key,
    required this.titles,
    required this.onAdd,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 0),
  });

  final List<String> titles;
  final void Function(String title) onAdd;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.dashboardAddWidgets,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          if (titles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.dashboardAllWidgetsAdded,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (final title in titles)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => onAdd(title),
                  icon: const Icon(Icons.add, size: 18),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(title),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// The "Hold to drag & reorder · tap ✕ to remove" hint shown above a
/// customizable grid while editing.
class EditModeHint extends StatelessWidget {
  const EditModeHint({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.drag_indicator, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Hold to drag & reorder · tap ✕ to remove',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
