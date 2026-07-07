import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/screen_error.dart';
import '../../core/time/local_date.dart';
import '../../domain/insights/body_energy_timeline.dart';
import '../../health/health_permissions.dart';
import '../../ui/components/health_connect_gate.dart';
import '../../ui/components/health_date_picker.dart';
import '../../ui/components/loading_state.dart';
import '../../ui/components/ov_card.dart';
import '../../ui/components/period_navigator.dart';
import 'body_energy_display.dart';
import 'body_energy_notifier.dart';
import 'body_energy_timeline_chart.dart';

/// Body-energy timeline detail pushed over the shell
/// (`/daily_readiness/body_energy/:bodyEnergyDate`). Port of the Kotlin
/// `BodyEnergyDetailsScreen`: a selected-day timeline chart + current-level and
/// charge/drain summary + confidence + input availability.
class BodyEnergyDetailsScreen extends ConsumerStatefulWidget {
  const BodyEnergyDetailsScreen({super.key, required this.date});

  /// ISO-8601 date argument (`yyyy-MM-dd`).
  final String date;

  @override
  ConsumerState<BodyEnergyDetailsScreen> createState() =>
      _BodyEnergyDetailsScreenState();
}

class _BodyEnergyDetailsScreenState
    extends ConsumerState<BodyEnergyDetailsScreen> {
  @override
  void initState() {
    super.initState();
    final date = parseIsoLocalDate(widget.date);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(bodyEnergyNotifierProvider.notifier).load(date);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bodyEnergyNotifierProvider);
    final notifier = ref.read(bodyEnergyNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Body energy')),
      body: HealthConnectGate(
        requiredPermissions: {HcPermissions.readHeartRate},
        showInlineSyncBanner: false,
        child: _BodyEnergyBody(
          state: state,
          onRefresh: notifier.refresh,
          onPreviousDay: notifier.previousDay,
          onNextDay: notifier.nextDay,
          onSelectDate: notifier.selectDate,
        ),
      ),
    );
  }
}

class _BodyEnergyBody extends StatelessWidget {
  const _BodyEnergyBody({
    required this.state,
    required this.onRefresh,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onSelectDate,
  });

  final BodyEnergyState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final void Function(LocalDate) onSelectDate;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    if (state.isLoading && result == null) {
      return const FullScreenLoading();
    }
    if (result == null && state.error != null) {
      return ErrorMessage(screenErrorText(state.error!));
    }

    final timeline = result?.latestDay;
    final display = buildBodyEnergyDisplay(timeline);
    final items = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DayNavigator(
          date: state.selectedDate,
          canGoForward: state.canGoForward,
          onPreviousDay: onPreviousDay,
          onNextDay: onNextDay,
          onOpenCalendar: () async {
            final picked = await showHealthDatePicker(
              context,
              selectedDate: state.selectedDate,
            );
            if (picked != null) onSelectDate(picked);
          },
        ),
      ),
      if (timeline == null)
        const _CardPad(
          child: _SimpleCard(
            title: 'Body energy',
            body: 'No Body Energy timeline is available for this day.',
          ),
        )
      else ...[
        _CardPad(child: _SummaryCard(display: display)),
        _CardPad(child: _TimelineCard(display: display)),
        _CardPad(child: _ReasonsCard(display: display)),
        _CardPad(child: _InputsCard(display: display)),
        if (display.timeline?.confidence == BodyEnergyConfidence.low)
          const _CardPad(
            child: _SimpleCard(
              title: 'Low confidence',
              body:
                  'Some timeline buckets have sparse Health Connect data, so this '
                  'estimate is approximate.',
            ),
          ),
      ],
      const SizedBox(height: 16),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: items,
          ),
        ),
      ),
    );
  }
}

// ── Cards ────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.display});

  final BodyEnergyDisplay display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeline = display.timeline;
    final accent = _scoreColor(timeline?.currentScore, theme.colorScheme);
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.battery_charging_full, color: accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Body energy',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text('Estimated from Health Connect data',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text(
                  timeline?.currentScore.toString() ?? '--',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _stat(theme, 'Start', '${timeline?.startScore ?? '--'}'),
                _stat(theme, 'Charged', '+${timeline?.charged ?? 0}'),
                _stat(theme, 'Drained', '-${timeline?.drained ?? 0}'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Confidence',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(
              _confidenceLabel(
                  timeline?.confidence ?? BodyEnergyConfidence.noData),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if ((timeline?.confidenceReason ?? '').isNotEmpty)
              Text(timeline!.confidenceReason,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.display});

  final BodyEnergyDisplay display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's timeline",
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (display.isEmpty)
              Text('No timeline data for this day.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant))
            else ...[
              BodyEnergyTimelineChart(
                points: display.chartPoints,
                influenceBars: display.influenceBars,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final influence in display.legendInfluences)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          color:
                              influenceColor(influence, theme.colorScheme),
                        ),
                        const SizedBox(width: 6),
                        Text(_influenceLabel(influence),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReasonsCard extends StatelessWidget {
  const _ReasonsCard({required this.display});

  final BodyEnergyDisplay display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why it changed',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (display.isEmpty || display.topReasons.isEmpty)
              Text('Not enough signal to explain today yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant))
            else
              for (final reason in display.topReasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 10,
                        height: 10,
                        color: influenceColor(
                            reason.influence, theme.colorScheme),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_influenceLabel(reason.influence),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        reason.direction == BodyEnergyReasonDirection.charge
                            ? '+${reason.roundedAmount}'
                            : '-${reason.roundedAmount}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: influenceColor(
                              reason.influence, theme.colorScheme),
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

class _InputsCard extends StatelessWidget {
  const _InputsCard({required this.display});

  final BodyEnergyDisplay display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inputs',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            for (final row in display.inputRows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      color: _statusColor(row.status, theme.colorScheme),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_inputLabel(row.kind),
                          style: theme.textTheme.bodyMedium),
                    ),
                    Text(_inputStatusText(row),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(body,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _CardPad extends StatelessWidget {
  const _CardPad({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: child,
      );
}

// ── Labels ───────────────────────────────────────────────────────────────────

Color _scoreColor(int? score, ColorScheme scheme) {
  if (score == null) return scheme.onSurfaceVariant;
  if (score >= 80) return scheme.primary;
  if (score >= 60) return scheme.tertiary;
  if (score >= 40) return scheme.secondary;
  return scheme.error;
}

Color _statusColor(BodyEnergyInputStatus status, ColorScheme scheme) {
  switch (status) {
    case BodyEnergyInputStatus.available:
      return scheme.primary;
    case BodyEnergyInputStatus.missing:
      return scheme.error;
    case BodyEnergyInputStatus.optional:
      return scheme.outline;
  }
}

String _confidenceLabel(BodyEnergyConfidence confidence) {
  switch (confidence) {
    case BodyEnergyConfidence.high:
      return 'High';
    case BodyEnergyConfidence.medium:
      return 'Medium';
    case BodyEnergyConfidence.low:
      return 'Low';
    case BodyEnergyConfidence.noData:
      return 'No data';
  }
}

String _influenceLabel(BodyEnergyPrimaryInfluence influence) {
  switch (influence) {
    case BodyEnergyPrimaryInfluence.sleepRecovery:
      return 'Sleep recovery';
    case BodyEnergyPrimaryInfluence.quietRest:
      return 'Quiet rest';
    case BodyEnergyPrimaryInfluence.exertion:
      return 'Exertion';
    case BodyEnergyPrimaryInfluence.elevatedHeartRate:
      return 'Elevated heart rate';
    case BodyEnergyPrimaryInfluence.recoveryDebt:
      return 'Recovery debt';
    case BodyEnergyPrimaryInfluence.noData:
      return 'No data';
    case BodyEnergyPrimaryInfluence.steady:
      return 'Steady';
  }
}

String _inputLabel(BodyEnergyInputKind kind) {
  switch (kind) {
    case BodyEnergyInputKind.heartRate:
      return 'Heart rate';
    case BodyEnergyInputKind.sleep:
      return 'Sleep';
    case BodyEnergyInputKind.workouts:
      return 'Workouts';
    case BodyEnergyInputKind.restingHeartRate:
      return 'Resting heart rate';
    case BodyEnergyInputKind.heartRateBaseline:
      return 'Heart-rate baseline';
    case BodyEnergyInputKind.hrv:
      return 'HRV';
    case BodyEnergyInputKind.respiratoryRate:
      return 'Respiratory rate';
    case BodyEnergyInputKind.previousScore:
      return 'Previous score';
    case BodyEnergyInputKind.calibration:
      return 'Calibration';
  }
}

String _inputStatusText(BodyEnergyInputRow row) {
  switch (row.kind) {
    case BodyEnergyInputKind.heartRate:
    case BodyEnergyInputKind.hrv:
    case BodyEnergyInputKind.respiratoryRate:
      final count = row.count;
      if (count != null) return '$count records';
      return _statusText(row.status);
    case BodyEnergyInputKind.sleep:
      final count = row.count;
      if (count != null) return '$count sessions';
      return _statusText(row.status);
    case BodyEnergyInputKind.workouts:
      final count = row.count;
      if (count != null) return '$count workouts';
      return _statusText(row.status);
    case BodyEnergyInputKind.previousScore:
      final value = row.value;
      if (value != null) return value;
      return _statusText(row.status);
    case BodyEnergyInputKind.calibration:
      return row.value ?? _statusText(row.status);
    case BodyEnergyInputKind.restingHeartRate:
    case BodyEnergyInputKind.heartRateBaseline:
      return _statusText(row.status);
  }
}

String _statusText(BodyEnergyInputStatus status) {
  switch (status) {
    case BodyEnergyInputStatus.available:
      return 'Available';
    case BodyEnergyInputStatus.missing:
      return 'Missing';
    case BodyEnergyInputStatus.optional:
      return 'Optional';
  }
}

/// Resolves a [ScreenError] into a display string (l10n lands later; literal
/// English fallbacks for now, matching `MetricDetailScaffold`).
String screenErrorText(ScreenError error) {
  switch (error) {
    case ScreenErrorMessage(:final text):
      return text;
    case ScreenErrorNotFound():
      return 'Not found.';
    case ScreenErrorMissingArgument():
      return 'Something went wrong.';
    case ScreenErrorPermissionDenied():
      return 'Permission denied.';
    case ScreenErrorHealthConnectUnavailable():
      return 'Health Connect is unavailable.';
  }
}

/// Parses an ISO `yyyy-MM-dd` argument into a [LocalDate] (falling back to today
/// on any malformed input).
LocalDate parseIsoLocalDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed != null) return LocalDate(parsed.year, parsed.month, parsed.day);
  return LocalDate.now();
}
