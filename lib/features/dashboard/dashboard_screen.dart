import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/presentation/screen_error.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../l10n/app_localizations.dart';
import '../../navigation/app_routes.dart';
import '../../state/app_providers.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/health_date_picker.dart';
import '../../ui/components/loading_state.dart';
import '../../ui/components/period_navigator.dart';
import '../../ui/components/permission_callout.dart';
import 'dashboard_metric_sections.dart';
import 'dashboard_notifier.dart';

/// Dashboard nav-suite branch body (rendered inside the adaptive scaffold).
///
/// Port of the Kotlin `DashboardScreen`: a day-navigated summary powered by one
/// aggregated [DashboardData] via [dashboardNotifierProvider], wrapped in the
/// [HealthConnectGate]. It shows a full-screen loader on the first load, a
/// pull-to-refresh list of grouped [MetricCard]s once data arrives, an inline
/// [PermissionCallout] for unacknowledged missing permissions, and surfaces
/// refresh failures (that leave existing data on screen) as a transient
/// SnackBar — the Kotlin toast behaviour.
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

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: PermissionCallout(
                title: l10n.messageMissingPermissionsTitle,
                body: l10n.messageMissingPermissionsBody,
                onGrant: notifier.grantPermissions,
                onDismiss: notifier.acknowledgePermissions,
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _DashboardQuickActions(),
          ),
          DashboardMetricSections(
            data: data,
            formatter: formatter,
            loadingMetrics: state.loadingMetrics,
            onOpenMetric: (location) => context.push(location),
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

/// The Log / Start-workout quick actions row (Kotlin `DashboardQuickActions`,
/// minus the dashboard-editing toggle which this port does not carry).
class _DashboardQuickActions extends StatelessWidget {
  const _DashboardQuickActions();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: () => context.go(AppRoutes.manualEntry),
            icon: const Icon(Icons.add),
            label: Text(l10n.dashboardActionLog),
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
            icon: const Icon(Icons.directions_run),
            label: Text(l10n.dashboardActionStartWorkout),
          ),
        ),
      ],
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
