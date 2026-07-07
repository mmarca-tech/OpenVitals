import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/presentation/screen_error.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../domain/model/activity_models.dart';
import '../../domain/model/dashboard_data.dart';
import '../../l10n/app_localizations.dart';
import '../../navigation/app_routes.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/health_date_picker.dart';
import '../../ui/components/loading_state.dart';
import '../../ui/components/metric_card.dart' show SourceChip;
import '../../ui/components/metric_stat_card.dart';
import '../../ui/components/period_navigator.dart';
import '../../ui/components/permission_callout.dart';
import '../../ui/components/summary_ring_card.dart';
import '../../ui/theme/app_colors.dart';
import '../activity/exercise_labels.dart';
import 'dashboard_notifier.dart';
import 'dashboard_summary_presentation.dart';

/// The OpenVitals summary dashboard — the nav-suite home branch rendered inside
/// the adaptive scaffold.
///
/// A faithful rebuild of the Kotlin `DashboardScreen` + the OpenVitals design
/// system: a day-navigated summary with two hero [SummaryRingCard]s (Steps and
/// Weekly cardio), a Log / Start quick-action row, a paged carousel of
/// [MetricStatCard] stat tiles with dot indicators, and a today's-activities
/// section. Data comes from one aggregated [DashboardData] via
/// [dashboardNotifierProvider], wrapped in the [HealthConnectGate]. Refresh
/// failures that leave data on screen surface as a transient SnackBar (the
/// Kotlin toast behaviour). The top bar (title + Mindfulness/Achievements/
/// Settings actions) is provided by the adaptive scaffold.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardNotifierProvider);
    final notifier = ref.read(dashboardNotifierProvider.notifier);
    final formatter = ref.watch(unitFormatterProvider);

    ref.listen<ScreenError?>(
      dashboardNotifierProvider.select((s) => s.error),
      (previous, next) {
        if (next == null) return;
        if (ref.read(dashboardNotifierProvider).data == null) return;
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(_errorText(next))));
        notifier.clearError();
      },
    );

    return HealthConnectGate(
      child: _DashboardBody(
        state: state,
        formatter: formatter,
        notifier: notifier,
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.state,
    required this.formatter,
    required this.notifier,
  });

  final DashboardState state;
  final UnitFormatter formatter;
  final DashboardNotifier notifier;

  static const double _gutter = 16;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = state.data;
    if (state.isLoading && data == null) {
      return const FullScreenLoading();
    }
    if (state.error != null && data == null) {
      return ErrorMessage(_errorText(state.error!));
    }
    if (data == null) {
      return const ErrorMessage('No dashboard data yet.');
    }

    final summary = buildDashboardSummary(data, formatter);

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter, vertical: 4),
            child: DayNavigator(
              date: data.date,
              canGoForward: state.canGoForward,
              onPreviousDay: notifier.previousDay,
              onNextDay: notifier.nextDay,
              onOpenCalendar: () => _openCalendar(context),
            ),
          ),
          if (state.unacknowledgedPermissions.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: _gutter, vertical: 4),
              child: PermissionCallout(
                title: l10n.messageMissingPermissionsTitle,
                body: l10n.messageMissingPermissionsBody,
                onGrant: notifier.grantPermissions,
                onDismiss: notifier.acknowledgePermissions,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(_gutter, 16, _gutter, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SummaryRingCard(
                    title: summary.steps.title,
                    value: summary.steps.value,
                    subtitle: summary.steps.subtitle,
                    accentColor: summary.steps.accent,
                    progress: summary.steps.progress,
                    onTap: () => context.push(summary.steps.location),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryRingCard(
                    title: summary.weeklyCardio.title,
                    value: summary.weeklyCardio.value,
                    subtitle: summary.weeklyCardio.subtitle,
                    accentColor: summary.weeklyCardio.accent,
                    progress: summary.weeklyCardio.progress,
                    onTap: () => context.push(summary.weeklyCardio.location),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(_gutter, 14, _gutter, 0),
            child: _DashboardQuickActions(),
          ),
          if (summary.tiles.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(_gutter, 16, _gutter, 4),
              child: _ThinDivider(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _MetricCarousel(
                tiles: summary.tiles,
                onOpen: (location) => context.push(location),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _ActivitiesSection(
            data: data,
            formatter: formatter,
            onOpen: (location) => context.push(location),
          ),
        ],
      ),
    );
  }

  Future<void> _openCalendar(BuildContext context) async {
    final picked = await showHealthDatePicker(
      context,
      selectedDate: state.selectedDate,
    );
    if (picked != null) notifier.selectDate(picked);
  }
}

/// The Log / Start-workout quick actions row + edit-dashboard button (Kotlin
/// `DashboardQuickActions`). Log is a tonal pill, Start a filled pill, both
/// full-width; the trailing 44dp edit button is a placeholder for the widget
/// reorder/edit mode.
class _DashboardQuickActions extends StatelessWidget {
  const _DashboardQuickActions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => context.push(AppRoutes.manualEntry),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
            ),
            icon: const Icon(Icons.add),
            label: Text(
              l10n.dashboardActionLog,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(
              AppRoutes.activityEntryLocation(
                mode: ActivityEntryMode.record.value,
              ),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.directions_run),
            label: Text(
              l10n.dashboardActionStartWorkout,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            // TODO(dashboard-edit): wire the widget reorder/edit mode.
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dashboard editing is coming soon.'),
              ),
            ),
            tooltip: 'Edit dashboard',
            icon: Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// A 1dp `outlineVariant` divider at 0.5 opacity (Kotlin dashboard section
/// separator).
class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}

/// The paged grid of [MetricStatCard] tiles (3 rows × 2 columns per page) with
/// centered dot indicators, mirroring the Kotlin `DashboardWidgetCarousel`.
class _MetricCarousel extends StatefulWidget {
  const _MetricCarousel({required this.tiles, required this.onOpen});

  final List<StatTileData> tiles;
  final void Function(String location) onOpen;

  static const int _columns = 2;
  static const int _rowsPerPage = 3;
  static const int _perPage = _columns * _rowsPerPage;
  static const double _tileHeight = 92;
  static const double _gap = 12;

  @override
  State<_MetricCarousel> createState() => _MetricCarouselState();
}

class _MetricCarouselState extends State<_MetricCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<List<StatTileData>> get _pages {
    final pages = <List<StatTileData>>[];
    for (var i = 0; i < widget.tiles.length; i += _MetricCarousel._perPage) {
      pages.add(
        widget.tiles.sublist(
          i,
          (i + _MetricCarousel._perPage).clamp(0, widget.tiles.length),
        ),
      );
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = _pages;
    final tilesOnTallestPage =
        widget.tiles.length.clamp(0, _MetricCarousel._perPage);
    final rows = (tilesOnTallestPage / _MetricCarousel._columns).ceil();
    final pageHeight = rows * _MetricCarousel._tileHeight +
        (rows - 1).clamp(0, rows) * _MetricCarousel._gap;

    return Column(
      children: [
        SizedBox(
          height: pageHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => _MetricGridPage(
              tiles: pages[index],
              onOpen: widget.onOpen,
            ),
          ),
        ),
        if (pages.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One page of the carousel: up to 3 rows of 2 stat tiles.
class _MetricGridPage extends StatelessWidget {
  const _MetricGridPage({required this.tiles, required this.onOpen});

  final List<StatTileData> tiles;
  final void Function(String location) onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = (tiles.length / _MetricCarousel._columns).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var row = 0; row < rows; row++) ...[
            if (row > 0) const SizedBox(height: _MetricCarousel._gap),
            SizedBox(
              height: _MetricCarousel._tileHeight,
              child: Row(
                children: [
                  for (var col = 0; col < _MetricCarousel._columns; col++) ...[
                    if (col > 0) const SizedBox(width: _MetricCarousel._gap),
                    Expanded(
                      child: _tileAt(row * _MetricCarousel._columns + col),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tileAt(int index) {
    if (index >= tiles.length) return const SizedBox.shrink();
    final tile = tiles[index];
    return MetricStatCard(
      title: tile.title,
      value: tile.value,
      unit: tile.unit,
      icon: tile.icon,
      accentColor: tile.accent,
      subtitle: tile.subtitle,
      message: tile.message,
      showTitle: tile.showTitle,
      progress: tile.progress,
      onTap: () => onOpen(tile.location),
    );
  }
}

/// The today's-activities section: a header with a "see all" chevron, then a
/// workout card per activity (or an empty-state placeholder). Port of the Kotlin
/// `dashboardActivitiesToday`.
class _ActivitiesSection extends StatelessWidget {
  const _ActivitiesSection({
    required this.data,
    required this.formatter,
    required this.onOpen,
  });

  final DashboardData data;
  final UnitFormatter formatter;
  final void Function(String location) onOpen;

  @override
  Widget build(BuildContext context) {
    final workouts = data.workouts.isNotEmpty
        ? data.workouts
        : (data.workout != null ? <ExerciseData>[data.workout!] : const <ExerciseData>[]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeaderRow(
          title: 'Activities',
          onTap: () => onOpen(AppRoutes.activity),
        ),
        if (workouts.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _ActivitiesEmptyCard(
              onTap: () => onOpen(AppRoutes.activity),
            ),
          )
        else
          for (final workout in workouts)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: _WorkoutCard(
                workout: workout,
                formatter: formatter,
                onTap: workout.id.isNotEmpty
                    ? () => onOpen(AppRoutes.activityDetailLocation(workout.id))
                    : null,
              ),
            ),
      ],
    );
  }
}

/// A tappable section header row: subdued title + trailing chevron (Kotlin
/// `DashboardActivitiesSectionHeader`).
class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// The dashboard workout card: an accent icon chip + "Workout" label + source
/// chip, then the exercise-type label, a large duration and the start time.
/// Port of the Kotlin `WorkoutCard`.
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.workout,
    required this.formatter,
    this.onTap,
  });

  final ExerciseData workout;
  final UnitFormatter formatter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timeLabel = DateFormat.jm().format(workout.startTime.toLocal());
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      clipBehavior: onTap == null ? Clip.none : Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AccentIconChip(
                    icon: exerciseTypeIcon(workout.exerciseType),
                    color: AppColors.workout,
                    size: 28,
                    iconSize: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Workout',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  if (workout.source.trim().isNotEmpty)
                    SourceChip(source: workout.source),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                exerciseTypeLabel(workout.exerciseType),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                formatter.duration(workout.durationMs),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round accent-tinted icon badge (Kotlin `AccentIconChip`): a circle filled
/// with the accent at 14% alpha and a coloured glyph.
class _AccentIconChip extends StatelessWidget {
  const _AccentIconChip({
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: iconSize ?? size * 0.5),
    );
  }
}

/// The empty-state activities card ("No activities recorded today").
class _ActivitiesEmptyCard extends StatelessWidget {
  const _ActivitiesEmptyCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      clipBehavior: onTap == null ? Clip.none : Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No activities recorded today.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

String _errorText(ScreenError error) => switch (error) {
      ScreenErrorMessage(:final text) => text,
      ScreenErrorNotFound() => 'Not found.',
      ScreenErrorMissingArgument() => 'Missing information.',
      ScreenErrorPermissionDenied() => 'Permission denied.',
      ScreenErrorHealthConnectUnavailable() => 'Health Connect is unavailable.',
    };
