import 'dart:async';

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

    final summary = buildDashboardSummary(data, formatter, l10n);
    // All data-present tiles in the user's saved order (hidden included, for the
    // edit grid); the carousel shows only the non-hidden subset.
    final orderedTiles = applyDashboardTileLayout(
      summary.tiles,
      order: state.tileOrder,
      includeHidden: true,
    );
    final visibleTiles = [
      for (final t in orderedTiles)
        if (!state.hiddenTiles.contains(t.title)) t,
    ];
    // Hero rings share the same edit mode + hidden set; only their order is
    // stored separately (they render in their own top row).
    final orderedRings = applyDashboardLayout(
      <RingCardData>[summary.steps, summary.weeklyCardio],
      (r) => r.title,
      order: state.ringOrder,
      includeHidden: true,
    );
    final visibleRings = [
      for (final r in orderedRings)
        if (!state.hiddenTiles.contains(r.title)) r,
    ];

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
          if (orderedRings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(_gutter, 16, _gutter, 0),
              child: state.editing
                  ? _HeroRingEditRow(
                      rings: visibleRings,
                      onReorder: (from, to) => notifier.setRingOrder(
                        reorderOntoDropTarget(
                          [for (final r in visibleRings) r.title],
                          from,
                          to,
                        ),
                      ),
                      onRemove: (title) => notifier.setTileHidden(title, true),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < visibleRings.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: SummaryRingCard(
                              title: visibleRings[i].title,
                              value: visibleRings[i].value,
                              subtitle: visibleRings[i].subtitle,
                              accentColor: visibleRings[i].accent,
                              progress: visibleRings[i].progress,
                              onTap: () =>
                                  context.push(visibleRings[i].location),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(_gutter, 14, _gutter, 0),
            child: _DashboardQuickActions(
              editing: state.editing,
              onToggleEdit: notifier.toggleEditing,
            ),
          ),
          if (orderedTiles.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(_gutter, 16, _gutter, 4),
              child: _ThinDivider(),
            ),
            if (state.editing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _MetricCarousel(
                  editing: true,
                  tiles: visibleTiles,
                  onReorder: (from, to) => notifier.setTileOrder(
                    reorderOntoDropTarget(
                      [for (final t in visibleTiles) t.title],
                      from,
                      to,
                    ),
                  ),
                  onRemove: (title) => notifier.setTileHidden(title, true),
                ),
              )
            else if (visibleTiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _MetricCarousel(
                  tiles: visibleTiles,
                  onOpen: (location) => context.push(location),
                ),
              ),
          ],
          // Outside the tiles-exist gate: with every widget removed there is
          // nothing to reorder, but the user still needs a way to add them back.
          if (state.editing)
            _HiddenWidgetsSection(
              titles: [
                for (final r in orderedRings)
                  if (state.hiddenTiles.contains(r.title)) r.title,
                for (final t in orderedTiles)
                  if (state.hiddenTiles.contains(t.title)) t.title,
              ],
              onAdd: (title) => notifier.setTileHidden(title, false),
            ),
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
  const _DashboardQuickActions({
    required this.editing,
    required this.onToggleEdit,
  });

  final bool editing;
  final VoidCallback onToggleEdit;

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
            onPressed: onToggleEdit,
            tooltip: editing ? 'Done' : 'Edit dashboard',
            isSelected: editing,
            icon: Icon(
              editing ? Icons.check : Icons.edit_outlined,
              color: editing ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The ✕ overlaid on a hero ring / stat tile in edit mode, which removes the
/// widget from the summary. Port of the Kotlin `onRemove` affordance.
class _RemoveWidgetButton extends StatelessWidget {
  const _RemoveWidgetButton({required this.onPressed});

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
/// tap-to-restore row. Port of the Kotlin `DashboardHiddenWidgets`.
class _HiddenWidgetsSection extends StatelessWidget {
  const _HiddenWidgetsSection({required this.titles, required this.onAdd});

  final List<String> titles;
  final void Function(String title) onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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

/// The paged grid of [MetricStatCard] tiles (up to 3 rows × 2 columns per page)
/// with centered dot indicators — the Flutter analogue of the Kotlin
/// `DashboardWidgetCarousel`.
///
/// In [editing] mode each tile becomes long-press draggable to reorder *within
/// the carousel itself*: the dragged tile floats under the finger (Flutter's
/// [LongPressDraggable] `feedback` is the Kotlin drag overlay), dragging near a
/// horizontal edge auto-pages (the Kotlin edge-scroll loop), and dropping on
/// another tile reorders across pages. Each tile also carries a remove button;
/// removed tiles move to the [_HiddenWidgetsSection] tray, so [tiles] is always
/// the visible set. Not editing: plain paged, tappable tiles.
class _MetricCarousel extends StatefulWidget {
  const _MetricCarousel({
    required this.tiles,
    this.editing = false,
    this.onOpen,
    this.onReorder,
    this.onRemove,
  });

  final List<StatTileData> tiles;
  final bool editing;
  final void Function(String location)? onOpen;
  final void Function(int from, int to)? onReorder;
  final void Function(String title)? onRemove;

  static const int _columns = 2;
  static const int _rowsPerPage = 3;
  static const int _perPage = _columns * _rowsPerPage;
  // Matches the Kotlin `DashboardCompactWidgetHeight`. Tiles fill this height
  // and centre their content in it, so it must stay close to the card's natural
  // content height or the tiles read as mostly empty.
  static const double _tileHeight = 82;
  // Horizontal gap between the two columns (Kotlin `DashboardWidgetGridSpacing`).
  static const double _gap = 12;
  // Vertical gap between rows — the same grid spacing.
  static const double _rowGap = 12;
  // Dragging within this distance of a horizontal edge auto-pages the carousel.
  static const double _edgeScrollThreshold = 56;
  static const Duration _edgeScrollInterval = Duration(milliseconds: 450);
  static const Duration _pageAnimation = Duration(milliseconds: 300);

  @override
  State<_MetricCarousel> createState() => _MetricCarouselState();
}

class _MetricCarouselState extends State<_MetricCarousel> {
  final PageController _controller = PageController();
  // Measures the pager viewport so drag positions can be tested against its edges.
  final GlobalKey _pagerKey = GlobalKey();
  int _page = 0;
  int? _draggingIndex;
  // Repeats while the drag rests in an edge zone. -1 = left, 1 = right, 0 = idle.
  Timer? _edgeScrollTimer;
  int _edgeScrollDirection = 0;

  @override
  void dispose() {
    _edgeScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _stopEdgeScroll() {
    _edgeScrollTimer?.cancel();
    _edgeScrollTimer = null;
    _edgeScrollDirection = 0;
  }

  void _endDrag() {
    _stopEdgeScroll();
    setState(() => _draggingIndex = null);
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

  /// Auto-advances the pager while a reorder drag hovers near a horizontal edge,
  /// one page per [_edgeScrollInterval] — the Flutter equivalent of the Kotlin
  /// carousel's edge-scroll `LaunchedEffect` loop.
  ///
  /// The repeat is driven by a [Timer], not by this callback: `onDragUpdate`
  /// only fires while the pointer *moves*, so a finger held still at the edge
  /// would page exactly once and then stall. This only re-arms the timer when
  /// the edge zone changes, so holding at the edge keeps paging.
  void _maybeEdgeScroll(Offset globalPosition, int pageCount) {
    if (pageCount <= 1) {
      _stopEdgeScroll();
      return;
    }
    final box = _pagerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final left = box.localToGlobal(Offset.zero).dx;
    final dx = globalPosition.dx - left;
    final width = box.size.width;
    final direction = dx <= _MetricCarousel._edgeScrollThreshold
        ? -1
        : dx >= width - _MetricCarousel._edgeScrollThreshold
            ? 1
            : 0;

    if (direction == _edgeScrollDirection) return;
    _stopEdgeScroll();
    if (direction == 0) return;

    _edgeScrollDirection = direction;
    _advancePage(direction, pageCount);
    _edgeScrollTimer = Timer.periodic(
      _MetricCarousel._edgeScrollInterval,
      (_) => _advancePage(direction, pageCount),
    );
  }

  void _advancePage(int direction, int pageCount) {
    final target = (_page + direction).clamp(0, pageCount - 1);
    if (target == _page) return;
    _controller.animateToPage(
      target,
      duration: _MetricCarousel._pageAnimation,
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = _pages;
    if (pages.isEmpty) return const SizedBox.shrink();
    final tilesOnTallestPage =
        widget.tiles.length.clamp(0, _MetricCarousel._perPage);
    final rows = (tilesOnTallestPage / _MetricCarousel._columns).ceil();
    final pageHeight = rows * _MetricCarousel._tileHeight +
        (rows - 1).clamp(0, rows) * _MetricCarousel._rowGap;

    return Column(
      children: [
        if (widget.editing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Icon(Icons.drag_indicator,
                    size: 16, color: scheme.onSurfaceVariant),
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
            ),
          ),
        SizedBox(
          key: _pagerKey,
          height: pageHeight,
          child: PageView.builder(
            controller: _controller,
            // While dragging, the drag gesture owns the pointer; edge-scroll
            // drives paging instead of user swipes.
            physics: _draggingIndex != null
                ? const NeverScrollableScrollPhysics()
                : null,
            itemCount: pages.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => _buildPage(context, index, pages),
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
                      color: i == _page ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPage(
    BuildContext context,
    int pageIndex,
    List<List<StatTileData>> pages,
  ) {
    final pageTiles = pages[pageIndex];
    final rows = (pageTiles.length / _MetricCarousel._columns).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = (constraints.maxWidth - _MetricCarousel._gap) /
              _MetricCarousel._columns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var row = 0; row < rows; row++) ...[
                if (row > 0) const SizedBox(height: _MetricCarousel._rowGap),
                SizedBox(
                  height: _MetricCarousel._tileHeight,
                  child: Row(
                    // Tiles fill the row height; the default centre alignment
                    // leaves them shrink-wrapped, with dead space above/below.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var col = 0;
                          col < _MetricCarousel._columns;
                          col++) ...[
                        if (col > 0)
                          const SizedBox(width: _MetricCarousel._gap),
                        Expanded(
                          child: _cell(
                            context,
                            localIndex: row * _MetricCarousel._columns + col,
                            flatIndex: pageIndex * _MetricCarousel._perPage +
                                row * _MetricCarousel._columns +
                                col,
                            pageTiles: pageTiles,
                            cellWidth: cellWidth,
                            pageCount: pages.length,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _cell(
    BuildContext context, {
    required int localIndex,
    required int flatIndex,
    required List<StatTileData> pageTiles,
    required double cellWidth,
    required int pageCount,
  }) {
    if (localIndex >= pageTiles.length) return const SizedBox.shrink();
    final tile = pageTiles[localIndex];

    if (!widget.editing) {
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
        onTap: () => widget.onOpen?.call(tile.location),
      );
    }

    final card = _editCard(context, tile);
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != flatIndex,
      onAcceptWithDetails: (details) =>
          widget.onReorder?.call(details.data, flatIndex),
      builder: (context, candidate, rejected) {
        return AnimatedScale(
          scale: candidate.isNotEmpty ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: LongPressDraggable<int>(
            data: flatIndex,
            onDragStarted: () => setState(() => _draggingIndex = flatIndex),
            onDragUpdate: (details) =>
                _maybeEdgeScroll(details.globalPosition, pageCount),
            onDragEnd: (_) => _endDrag(),
            onDraggableCanceled: (_, _) => _endDrag(),
            feedback: SizedBox(
              width: cellWidth,
              height: _MetricCarousel._tileHeight,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                child: _editCard(context, tile),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: card),
            child: card,
          ),
        );
      },
    );
  }

  Widget _editCard(BuildContext context, StatTileData tile) {
    return Stack(
      children: [
        Positioned.fill(
          child: MetricStatCard(
            title: tile.title,
            value: tile.value,
            unit: tile.unit,
            icon: tile.icon,
            accentColor: tile.accent,
            subtitle: tile.subtitle,
            message: tile.message,
            showTitle: tile.showTitle,
            progress: tile.progress,
            // No navigation while editing.
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: _RemoveWidgetButton(
            onPressed: () => widget.onRemove?.call(tile.title),
          ),
        ),
      ],
    );
  }
}

/// Edit-mode hero-ring row: the visible [SummaryRingCard]s (Steps / Weekly
/// cardio) become long-press draggable to swap and carry a remove button,
/// mirroring the carousel's edit-mode tiles but for the large square ring cards.
/// Removed rings move to the [_HiddenWidgetsSection] tray.
class _HeroRingEditRow extends StatelessWidget {
  const _HeroRingEditRow({
    required this.rings,
    required this.onReorder,
    required this.onRemove,
  });

  final List<RingCardData> rings;
  final void Function(int from, int to) onReorder;
  final void Function(String title) onRemove;

  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - _gap) / 2;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rings.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(child: _cell(context, i, cellWidth)),
            ],
          ],
        );
      },
    );
  }

  Widget _cell(BuildContext context, int index, double cellWidth) {
    final ring = rings[index];
    final card = _card(context, ring);
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => onReorder(details.data, index),
      builder: (context, candidate, rejected) {
        return AnimatedScale(
          scale: candidate.isNotEmpty ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: LongPressDraggable<int>(
            data: index,
            feedback: SizedBox(
              width: cellWidth,
              height: cellWidth,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                borderRadius: BorderRadius.circular(24),
                child: _card(context, ring),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.25, child: card),
            child: card,
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, RingCardData ring) {
    return Stack(
      children: [
        SummaryRingCard(
          title: ring.title,
          value: ring.value,
          subtitle: ring.subtitle,
          accentColor: ring.accent,
          progress: ring.progress,
          // No navigation while editing.
        ),
        Positioned(
          top: 2,
          right: 2,
          child: _RemoveWidgetButton(onPressed: () => onRemove(ring.title)),
        ),
      ],
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
