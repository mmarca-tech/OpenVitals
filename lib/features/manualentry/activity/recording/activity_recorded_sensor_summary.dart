import 'package:flutter/material.dart';

import '../../../../core/presentation/unit_formatter.dart';
import '../../../../domain/model/ble_sensor_models.dart';
import '../../../../domain/model/heart_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../ui/charts/sparkline_chart.dart';
import '../../../../ui/components/ov_surface.dart';
import '../../../../ui/theme/app_colors.dart';

/// Port of the Kotlin `ActivityRecordedSensorSummary` (in
/// `recording/ActivityRecordingSensorUi.kt`): what a finished recording — or an
/// activity being edited — captured from connected BLE sensors.
///
/// Renders nothing when no sensor produced samples, which is the common case
/// for a hand-typed entry.
class ActivityRecordedSensorSummary extends StatelessWidget {
  const ActivityRecordedSensorSummary({
    super.key,
    required this.samples,
    required this.unitFormatter,
    this.savedHeartRateSamples = const <HeartRateSample>[],
  });

  final BleRecordingSampleBuffer samples;
  final UnitFormatter unitFormatter;

  /// Heart-rate samples read back from a saved session, used when this entry is
  /// being edited rather than freshly recorded.
  final List<HeartRateSample> savedHeartRateSamples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final heartRateSamples = samples.heartRateSamples.isNotEmpty
        ? [
            for (final sample in samples.heartRateSamples)
              HeartRateSample(
                time: sample.time,
                beatsPerMinute: sample.beatsPerMinute,
                source: 'sensor',
              ),
          ]
        : savedHeartRateSamples;

    final hasOtherSamples = samples.powerSamples.isNotEmpty ||
        samples.cyclingCadenceSamples.isNotEmpty ||
        samples.speedSamples.isNotEmpty ||
        samples.stepsCadenceSamples.isNotEmpty;

    if (heartRateSamples.isEmpty && !hasOtherSamples) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (heartRateSamples.isNotEmpty)
          _HeartRateSummaryCard(samples: heartRateSamples),
        if (hasOtherSamples)
          OpenVitalsSurface(
            style: OpenVitalsSurfaceStyle.metric,
            contentPadding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Text(l10n.activityRecordingSensorsRecordedTitle,
                    style: theme.textTheme.titleSmall),
                for (final row in _metricRows(l10n))
                  Text(row, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }

  /// The average power / cadence / speed lines, in the Kotlin order. Each is
  /// omitted when its sensor produced nothing.
  List<String> _metricRows(AppLocalizations l10n) {
    final rows = <String>[];

    final averagePower = samples.averagePowerWatts();
    if (averagePower != null) {
      rows.add('${l10n.metricAveragePower}: '
          '${unitFormatter.power(averagePower).text}');
    }

    if (samples.cyclingCadenceSamples.isNotEmpty) {
      final average = _average([
        for (final sample in samples.cyclingCadenceSamples) sample.rpm.toDouble(),
      ]);
      // Kotlin truncates the average to a whole rpm before formatting.
      rows.add('${l10n.metricCyclingCadence}: '
          '${unitFormatter.cadence(average.truncateToDouble()).text}');
    }

    if (samples.speedSamples.isNotEmpty) {
      final average = _average([
        for (final sample in samples.speedSamples) sample.metersPerSecond,
      ]);
      rows.add('${l10n.metricAverageSpeed}: '
          '${unitFormatter.speed(average).text}');
    }

    return rows;
  }

  static double _average(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;
}

/// A compact heart-rate trace plus its min/avg/max.
///
/// The Kotlin app renders `ActivityHeartRateChartCard`, a full time-axis chart
/// keyed to the session range. No equivalent chart widget exists in this app
/// yet, so this shows a sparkline over the samples in order. Replacing it with
/// the real chart belongs with the recording pass, where the chart is also
/// needed live.
class _HeartRateSummaryCard extends StatelessWidget {
  const _HeartRateSummaryCard({required this.samples});

  final List<HeartRateSample> samples;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bpms = [for (final sample in samples) sample.beatsPerMinute];
    final min = bpms.reduce((a, b) => a < b ? a : b);
    final max = bpms.reduce((a, b) => a > b ? a : b);
    final average = (bpms.reduce((a, b) => a + b) / bpms.length).round();

    return OpenVitalsSurface(
      style: OpenVitalsSurfaceStyle.metric,
      contentPadding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text('Heart rate', style: theme.textTheme.titleSmall),
          if (bpms.length > 1)
            SizedBox(
              height: 56,
              child: SparklineChart(
                values: [for (final bpm in bpms) bpm.toDouble()],
                accentColor: AppColors.heart,
              ),
            ),
          Text(
            'Avg $average bpm • min $min bpm • max $max bpm',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
