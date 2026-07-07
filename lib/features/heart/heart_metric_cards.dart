import 'package:flutter/material.dart';

import '../../ui/components/ov_card.dart';

/// A label → value statistics card used across the heart + vitals detail
/// screens, a trimmed port of the various Kotlin `*StatisticsContent` grids.
class HeartStatisticsCard extends StatelessWidget {
  const HeartStatisticsCard({
    super.key,
    required this.rows,
    required this.accentColor,
    this.title = 'Statistics',
  });

  final List<(String, String)> rows;
  final Color accentColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.$1, style: theme.textTheme.bodyMedium),
                    Text(
                      row.$2,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
