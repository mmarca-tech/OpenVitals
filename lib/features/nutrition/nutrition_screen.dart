import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/period/period_range_preference_key.dart';
import '../../core/presentation/display_value.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../di/providers.dart';
import '../../domain/model/nutrition_models.dart';
import '../../state/app_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/metric_card.dart';
import '../../ui/components/metric_detail_scaffold.dart';
import '../../ui/components/ov_card.dart';
import '../../ui/theme/app_colors.dart';
import '../../health/health_permissions.dart';
import 'nutrition_formatting.dart';
import 'nutrition_metric.dart';
import 'nutrition_notifier.dart';

/// The nutrition overview / nutrient-breakdown screen, ported from the Kotlin
/// `NutritionScreen` + `nutritionContent`.
///
/// Reuses the [NutritionMetric.caloriesIn] notifier for its data and renders the
/// ~50-nutrient breakdown grouped OVERVIEW / CARBS / FATS / VITAMINS / MINERALS
/// / OTHER, with each tracked nutrient's period total formatted via the
/// per-nutrient [nutrientDisplayValue].
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = nutritionMetricProvider(NutritionMetric.caloriesIn);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final formatter = ref.watch(unitFormatterProvider);
    final weekMode = ref.watch(preferencesRepositoryProvider).weekPeriodMode;
    final syncPaused = !ref.watch(healthConnectSyncEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition')),
      body: HealthConnectGate(
        requiredPermissions: {HcPermissions.readNutrition},
        showInlineSyncBanner: false,
        child: MetricDetailScaffold(
          rangePreferenceKey: PeriodRangePreferenceKey.nutrition,
          onRefresh: notifier.refresh,
          isLoading: state.isLoading,
          screenError: state.error,
          weekPeriodMode: weekMode,
          syncPaused: syncPaused,
          onSelectionChanged: (selection) => notifier.load(selection),
          content: (period) => _content(context, state, formatter),
        ),
      ),
    );
  }
}

List<Widget> _content(
  BuildContext context,
  NutritionState state,
  UnitFormatter formatter,
) {
  final l10n = AppLocalizations.of(context);
  if (!state.hasData) {
    if (state.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    return [
      _padded(
        const MetricCardPlaceholder(
          title: 'Nutrition',
          icon: Icons.restaurant_outlined,
          accentColor: AppColors.nutrition,
          message: 'No nutrition logged for this period.',
        ),
      ),
    ];
  }

  // Per-nutrient period totals across the loaded daily macros.
  double totalFor(NutritionNutrient nutrient) => state.dailyMacros
      .fold<double>(0.0, (sum, day) => sum + day.valueFor(nutrient));

  final widgets = <Widget>[];
  for (final group in NutritionNutrientGroup.values) {
    final nutrients = NutritionNutrient.values
        .where((nutrient) => nutrient.group == group)
        .toList();
    // The overview group always shows its four primary nutrients; every other
    // group shows only nutrients with tracked (> 0) totals for the period.
    final tiles = <_NutrientTile>[];
    for (final nutrient in nutrients) {
      final total = totalFor(nutrient);
      if (group != NutritionNutrientGroup.overview && total <= 0.0) continue;
      tiles.add(
        _NutrientTile(
          title: nutrientTitle(nutrient, l10n),
          value: nutrientDisplayValue(nutrient, total, formatter),
          color: nutrientColor(nutrient),
        ),
      );
    }
    if (tiles.isEmpty) continue;

    widgets.add(SectionHeader(
      group == NutritionNutrientGroup.overview
          ? 'Overview'
          : nutrientGroupTitle(group),
    ));
    widgets.add(_padded(_NutrientTileGrid(tiles: tiles)));
  }

  return widgets;
}

Widget _padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: child,
    );

class _NutrientTile {
  const _NutrientTile({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final DisplayValue value;
  final Color color;
}

/// A two-column grid of nutrient total tiles.
class _NutrientTileGrid extends StatelessWidget {
  const _NutrientTileGrid({required this.tiles});

  final List<_NutrientTile> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final left = tiles[i];
      final right = i + 1 < tiles.length ? tiles[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _NutrientTileCard(tile: left)),
                const SizedBox(width: 8),
                Expanded(
                  child: right != null
                      ? _NutrientTileCard(tile: right)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _NutrientTileCard extends StatelessWidget {
  const _NutrientTileCard({required this.tile});

  final _NutrientTile tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_outlined, color: tile.color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tile.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MetricValueRow(value: tile.value.value, unit: tile.value.unit),
          ],
        ),
      ),
    );
  }
}
