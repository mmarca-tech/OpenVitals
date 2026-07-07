import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/period/period_range_preference_key.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../di/providers.dart';
import '../../domain/model/activity_models.dart';
import '../../health/health_permissions.dart';
import '../../navigation/app_routes.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/metric_card.dart';
import '../../ui/components/metric_detail_scaffold.dart';
import '../../ui/components/ov_card.dart';
import '../../ui/theme/app_colors.dart';
import 'activities_notifier.dart';
import 'exercise_labels.dart';

final DateFormat _workoutTimeFormat = DateFormat('EEE d MMM · HH:mm');

/// Activities nav-suite branch body: the period workout list, ported from the
/// Kotlin `ActivitiesScreen`. Wrapped in the [HealthConnectGate] (exercise read)
/// and driven by the [MetricDetailScaffold] like the metric detail screens.
class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activitiesNotifierProvider);
    final notifier = ref.read(activitiesNotifierProvider.notifier);
    final formatter = ref.watch(unitFormatterProvider);
    final weekMode = ref.watch(preferencesRepositoryProvider).weekPeriodMode;
    final syncPaused = !ref.watch(healthConnectSyncEnabledProvider);

    return HealthConnectGate(
      requiredPermissions: {HcPermissions.readExercise},
      showInlineSyncBanner: false,
      child: MetricDetailScaffold(
        rangePreferenceKey: PeriodRangePreferenceKey.activities,
        onRefresh: notifier.refresh,
        isLoading: state.isLoading,
        screenError: state.error,
        weekPeriodMode: weekMode,
        syncPaused: syncPaused,
        onSelectionChanged: (selection) => notifier.load(selection),
        content: (period) => _content(context, state, formatter),
      ),
    );
  }
}

List<Widget> _content(
  BuildContext context,
  ActivitiesState state,
  UnitFormatter formatter,
) {
  if (state.workouts.isEmpty && state.plannedWorkouts.isEmpty) {
    if (state.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    return const [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: MetricCardPlaceholder(
          title: 'Workouts',
          icon: Icons.directions_run,
          accentColor: AppColors.workout,
          message: 'No workouts recorded for this period.',
        ),
      ),
    ];
  }

  return [
    if (state.workouts.isNotEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: _ActivitySummaryCard(state: state, formatter: formatter),
      ),
    if (state.plannedWorkouts.isNotEmpty) ...[
      const SectionHeader('Planned'),
      for (final planned in state.plannedWorkouts)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _PlannedWorkoutTile(planned: planned, formatter: formatter),
        ),
    ],
    if (state.workouts.isNotEmpty) ...[
      const SectionHeader('Workouts'),
      for (final workout in state.workouts)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _WorkoutTile(
            workout: workout,
            formatter: formatter,
            onTap: () => context.push(
              AppRoutes.activityDetailLocation(workout.id),
            ),
          ),
        ),
    ],
  ];
}

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({required this.state, required this.formatter});

  final ActivitiesState state;
  final UnitFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = state.workouts.length;
    final distance = state.totalDistanceMeters;
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _summary(theme, '$count', count == 1 ? 'workout' : 'workouts'),
            _summary(theme, formatter.duration(state.totalDurationMs), 'time'),
            if (distance > 0)
              _summary(theme, formatter.distance(distance).text, 'distance'),
          ],
        ),
      ),
    );
  }

  Widget _summary(ThemeData theme, String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({
    required this.workout,
    required this.formatter,
    required this.onTap,
  });

  final ExerciseData workout;
  final UnitFormatter formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = workout.title?.trim().isNotEmpty == true
        ? workout.title!
        : exerciseTypeLabel(workout.exerciseType);
    final subtitleParts = <String>[
      formatter.duration(workout.durationMs),
      if ((workout.totalDistanceMeters ?? 0) > 0)
        formatter.distance(workout.totalDistanceMeters!).text,
    ];
    return OpenVitalsCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _AccentIcon(icon: exerciseTypeIcon(workout.exerciseType)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(
                    _workoutTimeFormat.format(workout.startTime.toLocal()),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (subtitleParts.isNotEmpty)
                    Text(
                      subtitleParts.join(' · '),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _PlannedWorkoutTile extends StatelessWidget {
  const _PlannedWorkoutTile({required this.planned, required this.formatter});

  final PlannedExerciseData planned;
  final UnitFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = planned.title?.trim().isNotEmpty == true
        ? planned.title!
        : exerciseTypeLabel(planned.exerciseType);
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _AccentIcon(icon: Icons.event_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(
                    planned.hasExplicitTime
                        ? _workoutTimeFormat.format(planned.startTime.toLocal())
                        : 'Planned',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

class _AccentIcon extends StatelessWidget {
  const _AccentIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.workout.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.workout, size: 20),
    );
  }
}
