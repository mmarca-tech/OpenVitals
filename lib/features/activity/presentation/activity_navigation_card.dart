import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/components/ov_card.dart';
import '../application/activity_navigation_display.dart';

/// The CoMaps guidance that was saved while this activity was recorded — the
/// streets, turns and distances the user was actually being given at the time.
///
/// App-local history: none of this came from, or ever goes to, Health Connect.
/// The rows arrive already built ([buildActivityNavigationRows]); this only
/// prints them.
class ActivityNavigationCard extends StatelessWidget {
  const ActivityNavigationCard({super.key, required this.rows});

  final List<ActivityNavigationRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.navigation_outlined,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(
                  l10n.activityDetailTabNavigation,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text(
                l10n.activityDetailNoNavigationContext,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            for (final (index, row) in rows.indexed) ...[
              if (index > 0)
                Divider(color: theme.colorScheme.outlineVariant, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(row.detail, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      row.meta,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
