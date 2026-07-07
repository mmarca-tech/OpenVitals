import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../navigation/app_routes.dart';

/// The Flutter analogue of the Kotlin `OpenVitalsAdaptiveScaffold`.
///
/// Wraps the [StatefulNavigationShell] holding the top-level branches
/// (dashboard, activities, add-entry, settings) with a Material 3 top app bar,
/// adaptive navigation, and a contextual Add action:
///
/// * **compact** width (< [_mediumBreakpoint]) → bottom [NavigationBar];
/// * **medium/expanded** width → side [NavigationRail] (extended past
///   [_expandedBreakpoint]).
///
/// Detail/entry routes are pushed onto the root navigator and therefore render
/// their own [Scaffold] over this shell rather than inside it.
class OpenVitalsAdaptiveScaffold extends StatelessWidget {
  const OpenVitalsAdaptiveScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const double _mediumBreakpoint = 600;
  static const double _expandedBreakpoint = 840;

  static const List<TopLevelDestination> _destinations =
      TopLevelDestination.values;

  void _goBranch(int index) {
    // `initialLocation: true` when re-tapping the current tab pops that branch
    // back to its root (the standard go_router StatefulShellRoute pattern).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  String _appBarTitle(AppLocalizations l10n, int index) =>
      index == TopLevelDestination.dashboard.branchIndex
          ? l10n.appName
          : navDestinationLabel(l10n, _destinations[index]);

  /// The dashboard top-bar actions (Mindfulness / Achievements / Settings),
  /// matching the OpenVitals design-system home `TopBar`. Only shown on the
  /// dashboard branch; other branches keep a bare app bar.
  List<Widget>? _appBarActions(BuildContext context, int index) {
    if (index != TopLevelDestination.dashboard.branchIndex) return null;
    final l10n = AppLocalizations.of(context);
    return [
      IconButton(
        tooltip: l10n.screenMindfulness,
        icon: const Icon(Icons.self_improvement_outlined),
        onPressed: () => context.push(AppRoutes.mindfulnessEntry),
      ),
      IconButton(
        tooltip: l10n.screenAchievements,
        icon: const Icon(Icons.workspace_premium_outlined),
        onPressed: () => context.push(AppRoutes.achievements),
      ),
      IconButton(
        tooltip: l10n.screenSettings,
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => _goBranch(TopLevelDestination.settings.branchIndex),
      ),
    ];
  }

  /// Contextual Add action, mirroring the Kotlin `addEntryActionForCurrentRoute`
  /// which surfaces an Add FAB on the Activities section (→ new activity entry).
  Widget? _floatingActionButton(BuildContext context, int index) {
    if (index != TopLevelDestination.activities.branchIndex) return null;
    final l10n = AppLocalizations.of(context);
    return FloatingActionButton.extended(
      onPressed: () => context.push(
        AppRoutes.activityEntryLocation(mode: ActivityEntryMode.record.value),
      ),
      icon: const Icon(Icons.add),
      label: Text(l10n.activityEntryRecordGps),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final int index = navigationShell.currentIndex;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useRail = constraints.maxWidth >= _mediumBreakpoint;
        final bool extendedRail = constraints.maxWidth >= _expandedBreakpoint;
        final fab = _floatingActionButton(context, index);

        return Scaffold(
          appBar: AppBar(
            title: Text(_appBarTitle(l10n, index)),
            centerTitle: false,
            actions: _appBarActions(context, index),
          ),
          floatingActionButton: fab,
          body: useRail
              ? _RailLayout(
                  index: index,
                  extended: extendedRail,
                  destinations: _destinations,
                  onSelected: _goBranch,
                  child: navigationShell,
                )
              : navigationShell,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: _goBranch,
                  destinations: [
                    for (final d in _destinations)
                      NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: navDestinationLabel(l10n, d),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// Localized label for a top-level nav destination. The [TopLevelDestination]
/// enum keeps a const English `label` for non-UI use (fallbacks, tests); this
/// maps each destination to its ARB catalog string for display. Dashboard uses
/// the Kotlin `bottom_nav_dashboard` ("Summary") label.
String navDestinationLabel(AppLocalizations l10n, TopLevelDestination d) {
  switch (d) {
    case TopLevelDestination.dashboard:
      return l10n.bottomNavDashboard;
    case TopLevelDestination.activities:
      return l10n.screenActivities;
    case TopLevelDestination.addEntry:
      return l10n.screenManualEntry;
    case TopLevelDestination.settings:
      return l10n.screenSettings;
  }
}

class _RailLayout extends StatelessWidget {
  const _RailLayout({
    required this.index,
    required this.extended,
    required this.destinations,
    required this.onSelected,
    required this.child,
  });

  final int index;
  final bool extended;
  final List<TopLevelDestination> destinations;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical -
                      kToolbarHeight)
                  .clamp(0.0, double.infinity),
            ),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: index,
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                onDestinationSelected: onSelected,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(navDestinationLabel(l10n, d)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: child),
      ],
    );
  }
}
