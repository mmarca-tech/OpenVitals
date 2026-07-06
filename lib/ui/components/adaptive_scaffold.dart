import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  String _appBarTitle(int index) =>
      index == TopLevelDestination.dashboard.branchIndex
          ? 'OpenVitals'
          : _destinations[index].label;

  /// Contextual Add action, mirroring the Kotlin `addEntryActionForCurrentRoute`
  /// which surfaces an Add FAB on the Activities section (→ new activity entry).
  Widget? _floatingActionButton(BuildContext context, int index) {
    if (index != TopLevelDestination.activities.branchIndex) return null;
    return FloatingActionButton.extended(
      onPressed: () => context.push(
        AppRoutes.activityEntryLocation(mode: ActivityEntryMode.record.value),
      ),
      icon: const Icon(Icons.add),
      label: const Text('New activity'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int index = navigationShell.currentIndex;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useRail = constraints.maxWidth >= _mediumBreakpoint;
        final bool extendedRail = constraints.maxWidth >= _expandedBreakpoint;
        final fab = _floatingActionButton(context, index);

        return Scaffold(
          appBar: AppBar(
            title: Text(_appBarTitle(index)),
            centerTitle: false,
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
                        label: d.label,
                      ),
                  ],
                ),
        );
      },
    );
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
                      label: Text(d.label),
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
