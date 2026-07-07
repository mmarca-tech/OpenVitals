import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../di/providers.dart';
import '../../domain/model/body_models.dart';
import '../../domain/model/vitals_models.dart';
import '../../navigation/app_routes.dart';
import '../../ui/components/ov_card.dart';
import '../../ui/theme/app_colors.dart';

/// The add-entry hub rendered inside the adaptive scaffold's "Add entry" branch.
///
/// Riverpod/Flutter port of the Kotlin `ManualEntryScreen` + `ManualEntryWidgets`:
/// a grid of entry-type tiles (in the user's saved order) that route to each
/// manual-entry form. The drag-to-reorder editing mode and per-tile write-
/// permission prompts are UI niceties left out of this batch — the tiles route
/// straight to the forms, which each guard writes behind a Health Connect gate.
class ManualEntryScreen extends ConsumerWidget {
  const ManualEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(preferencesRepositoryProvider).manualEntryWidgetOrder();
    final ids = _widgetIdsFromStored(stored);
    final specs = [
      for (final id in ids)
        if (_specsById[id] != null) _specsById[id]!,
    ];

    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(12),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final spec in specs)
          _ManualEntryTile(
            spec: spec,
            onTap: () => context.push(spec.location),
          ),
      ],
    );
  }
}

class _ManualEntryTile extends StatelessWidget {
  const _ManualEntryTile({required this.spec, required this.onTap});

  final _ManualEntryWidgetSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OpenVitalsCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(spec.icon, color: spec.accentColor, size: 30),
            Text(
              spec.title,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Port of the Kotlin `ManualEntryWidgetId` enum. The `storageName` matches the
/// Kotlin enum-constant name persisted in the widget-order preference.
enum _ManualEntryWidgetId {
  hydration('HYDRATION'),
  carbs('CARBS'),
  activity('ACTIVITY'),
  mindfulness('MINDFULNESS'),
  weight('WEIGHT'),
  height('HEIGHT'),
  bodyFat('BODY_FAT'),
  bloodPressure('BLOOD_PRESSURE'),
  spo2('SPO2'),
  respiratoryRate('RESPIRATORY_RATE'),
  bodyTemperature('BODY_TEMPERATURE');

  const _ManualEntryWidgetId(this.storageName);

  final String storageName;

  static _ManualEntryWidgetId? fromStorage(String value) {
    for (final id in values) {
      if (id.storageName == value) return id;
    }
    return null;
  }
}

/// The default order (Kotlin `DefaultManualEntryWidgetIds`).
const List<_ManualEntryWidgetId> _defaultWidgetIds = _ManualEntryWidgetId.values;

/// Resolves the stored order into widget ids, falling back to the default set.
/// Port of the Kotlin `manualEntryWidgetIdsFromStored`.
List<_ManualEntryWidgetId> _widgetIdsFromStored(List<String>? stored) {
  if (stored == null) return _defaultWidgetIds;
  if (stored.isEmpty) return const <_ManualEntryWidgetId>[];
  final parsed = <_ManualEntryWidgetId>[];
  final seen = <_ManualEntryWidgetId>{};
  for (final raw in stored) {
    final id = _ManualEntryWidgetId.fromStorage(raw);
    if (id != null && seen.add(id)) parsed.add(id);
  }
  return parsed.isEmpty ? _defaultWidgetIds : parsed;
}

class _ManualEntryWidgetSpec {
  const _ManualEntryWidgetSpec({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.location,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final String location;
}

const Color _oxygenColor = Color(0xFF00897B);
const Color _respiratoryColor = Color(0xFF5E97F6);
const Color _temperatureColor = Color(0xFFFF7043);

final Map<_ManualEntryWidgetId, _ManualEntryWidgetSpec> _specsById = {
  _ManualEntryWidgetId.hydration: const _ManualEntryWidgetSpec(
    title: 'Hydration',
    icon: Icons.local_drink_outlined,
    accentColor: AppColors.hydration,
    location: AppRoutes.hydrationEntry,
  ),
  _ManualEntryWidgetId.carbs: const _ManualEntryWidgetSpec(
    title: 'Carbs',
    icon: Icons.restaurant_outlined,
    accentColor: AppColors.nutrition,
    location: AppRoutes.carbsEntry,
  ),
  _ManualEntryWidgetId.activity: _ManualEntryWidgetSpec(
    title: 'Activity',
    icon: Icons.directions_run_outlined,
    accentColor: AppColors.workout,
    location: AppRoutes.activityEntryLocation(),
  ),
  _ManualEntryWidgetId.mindfulness: const _ManualEntryWidgetSpec(
    title: 'Mindfulness',
    icon: Icons.self_improvement,
    accentColor: AppColors.mindfulness,
    location: AppRoutes.mindfulnessEntry,
  ),
  _ManualEntryWidgetId.weight: _ManualEntryWidgetSpec(
    title: 'Weight',
    icon: Icons.monitor_weight_outlined,
    accentColor: AppColors.weight,
    location: AppRoutes.bodyMeasurementEntryLocation(
      BodyMeasurementType.weight.storageName,
    ),
  ),
  _ManualEntryWidgetId.height: _ManualEntryWidgetSpec(
    title: 'Height',
    icon: Icons.straighten_outlined,
    accentColor: AppColors.weight,
    location: AppRoutes.bodyMeasurementEntryLocation(
      BodyMeasurementType.height.storageName,
    ),
  ),
  _ManualEntryWidgetId.bodyFat: _ManualEntryWidgetSpec(
    title: 'Body fat',
    icon: Icons.monitor_weight_outlined,
    accentColor: AppColors.bodyFat,
    location: AppRoutes.bodyMeasurementEntryLocation(
      BodyMeasurementType.bodyFat.storageName,
    ),
  ),
  _ManualEntryWidgetId.bloodPressure: _ManualEntryWidgetSpec(
    title: 'Blood pressure',
    icon: Icons.favorite,
    accentColor: AppColors.vitals,
    location: AppRoutes.vitalsMeasurementEntryLocation(
      VitalsMeasurementType.bloodPressure.storageName,
    ),
  ),
  _ManualEntryWidgetId.spo2: _ManualEntryWidgetSpec(
    title: 'Blood oxygen',
    icon: Icons.favorite_border,
    accentColor: _oxygenColor,
    location: AppRoutes.vitalsMeasurementEntryLocation(
      VitalsMeasurementType.spo2.storageName,
    ),
  ),
  _ManualEntryWidgetId.respiratoryRate: _ManualEntryWidgetSpec(
    title: 'Respiratory rate',
    icon: Icons.air,
    accentColor: _respiratoryColor,
    location: AppRoutes.vitalsMeasurementEntryLocation(
      VitalsMeasurementType.respiratoryRate.storageName,
    ),
  ),
  _ManualEntryWidgetId.bodyTemperature: _ManualEntryWidgetSpec(
    title: 'Body temperature',
    icon: Icons.device_thermostat,
    accentColor: _temperatureColor,
    location: AppRoutes.vitalsMeasurementEntryLocation(
      VitalsMeasurementType.bodyTemperature.storageName,
    ),
  ),
};
