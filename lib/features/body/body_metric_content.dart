import 'package:flutter/material.dart';

import '../../core/period/period_titles.dart';
import '../../core/period/time_range.dart';
import '../../core/presentation/display_value.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../core/time/local_date.dart';
import '../../domain/query/body_period_data.dart';
import '../../ui/charts/line_chart.dart';
import '../../ui/components/metric_card.dart';
import '../heart/heart_metric_cards.dart';
import 'body_metric.dart';
import 'body_metric_notifier.dart';
import 'body_summary.dart';

/// Builds the metric content for a body detail screen. A trimmed port of the
/// Kotlin per-metric `*Content` functions (`BodyMetricContent.kt`), reduced to
/// the primary hero card + period line chart + statistics.
List<Widget> bodyMetricContent(
  BodyMetric metric,
  BodyMetricState state,
  UnitFormatter formatter,
  DatePeriod period,
) {
  final data = state.data;
  if (data == null) {
    if (state.isLoading) return const [_LoadingBlock()];
    return [_placeholder(metric)];
  }
  final summary = BodySummary.fromPeriod(data);
  final view = _viewFor(metric, data, summary, formatter);
  if (view.latest == null) {
    return state.isLoading ? const [_LoadingBlock()] : [_placeholder(metric)];
  }
  return _build(metric, state, period, view, formatter);
}

/// Overview rows (latest value per metric) for the `/body` section screen.
List<(BodyMetric, DisplayValue?)> bodyOverviewValues(
  BodyPeriodData data,
  UnitFormatter formatter,
) {
  final summary = BodySummary.fromPeriod(data);
  return [
    for (final metric in BodyMetric.values)
      (metric, _viewFor(metric, data, summary, formatter).latest),
  ];
}

// ── Per-metric view resolution ───────────────────────────────────────────────

class _MetricView {
  const _MetricView({
    required this.latest,
    required this.entries,
    required this.format,
    this.extraStats = const <(String, String)>[],
  });

  /// The hero (latest) value, or null when there is no data for this metric.
  final DisplayValue? latest;

  /// Time-ordered (time, value) pairs feeding the chart + statistics.
  final List<(DateTime, double)> entries;
  final DisplayValue Function(double) format;
  final List<(String, String)> extraStats;
}

_MetricView _viewFor(
  BodyMetric metric,
  BodyPeriodData data,
  BodySummary summary,
  UnitFormatter formatter,
) {
  switch (metric) {
    case BodyMetric.weight:
      return _MetricView(
        latest: summary.latestWeightKg == null
            ? null
            : formatter.weight(summary.latestWeightKg!),
        entries: [for (final e in data.weightEntries) (e.time, e.weightKg)],
        format: formatter.weight,
        extraStats: [
          if (summary.weightChangeKg != null)
            ('Change', _signed(formatter.weight(summary.weightChangeKg!))),
        ],
      );
    case BodyMetric.height:
      return _MetricView(
        latest: summary.latestHeightCm == null
            ? null
            : formatter.height(summary.latestHeightCm!),
        entries: [for (final e in data.heightEntries) (e.time, e.heightCm)],
        format: formatter.height,
      );
    case BodyMetric.bmi:
      final heightCm = summary.heightCm;
      final entries = (heightCm != null && heightCm > 0.0)
          ? [
              for (final e in data.weightEntries)
                (e.time, e.weightKg / _heightMetersSquared(heightCm)),
            ]
          : const <(DateTime, double)>[];
      return _MetricView(
        latest: summary.bmi == null
            ? null
            : DisplayValue(formatter.decimal(summary.bmi!, 1), ''),
        entries: entries,
        format: (v) => DisplayValue(formatter.decimal(v, 1), ''),
        extraStats: [
          if (summary.ffmi != null)
            ('FFMI', formatter.decimal(summary.ffmi!, 1)),
          if (summary.adjustedFfmi != null)
            ('Adjusted FFMI', formatter.decimal(summary.adjustedFfmi!, 1)),
        ],
      );
    case BodyMetric.ffmi:
      return _MetricView(
        latest: summary.ffmi == null
            ? null
            : DisplayValue(formatter.decimal(summary.ffmi!, 1), ''),
        entries: const <(DateTime, double)>[],
        format: (v) => DisplayValue(formatter.decimal(v, 1), ''),
        extraStats: [
          if (summary.adjustedFfmi != null)
            ('Adjusted FFMI', formatter.decimal(summary.adjustedFfmi!, 1)),
          if (summary.bmi != null) ('BMI', formatter.decimal(summary.bmi!, 1)),
          if (summary.latestBodyFatPercent != null)
            ('Body fat', formatter.percent(summary.latestBodyFatPercent!).text),
        ],
      );
    case BodyMetric.bodyFat:
      return _MetricView(
        latest: summary.latestBodyFatPercent == null
            ? null
            : formatter.percent(summary.latestBodyFatPercent!),
        entries: [for (final e in data.bodyFatEntries) (e.time, e.percent)],
        format: formatter.percent,
      );
    case BodyMetric.leanMass:
      return _MetricView(
        latest: summary.latestLeanMassKg == null
            ? null
            : formatter.bodyMass(summary.latestLeanMassKg!),
        entries: [for (final e in data.leanMassEntries) (e.time, e.massKg)],
        format: formatter.bodyMass,
      );
    case BodyMetric.bmr:
      return _MetricView(
        latest: summary.latestBmrKcal == null
            ? null
            : formatter.energy(summary.latestBmrKcal!),
        entries: [for (final e in data.bmrEntries) (e.time, e.kcalPerDay)],
        format: formatter.energy,
      );
    case BodyMetric.boneMass:
      return _MetricView(
        latest: summary.latestBoneMassKg == null
            ? null
            : formatter.bodyMass(summary.latestBoneMassKg!, decimals: 2),
        entries: [for (final e in data.boneMassEntries) (e.time, e.massKg)],
        format: (v) => formatter.bodyMass(v, decimals: 2),
      );
    case BodyMetric.bodyWaterMass:
      return _MetricView(
        latest: summary.latestBodyWaterMassKg == null
            ? null
            : formatter.bodyMass(summary.latestBodyWaterMassKg!, decimals: 2),
        entries: [
          for (final e in data.bodyWaterMassEntries) (e.time, e.massKg),
        ],
        format: (v) => formatter.bodyMass(v, decimals: 2),
      );
  }
}

// ── Layout ───────────────────────────────────────────────────────────────────

List<Widget> _build(
  BodyMetric metric,
  BodyMetricState state,
  DatePeriod period,
  _MetricView view,
  UnitFormatter formatter,
) {
  final range = state.selectedRange;
  final sorted = [...view.entries]..sort((a, b) => a.$1.compareTo(b.$1));
  final values = sorted.map((e) => e.$2).toList();

  final widgets = <Widget>[
    _hero(metric, view.latest!),
    if (sorted.length > 1)
      _padded(MetricLineChart(
        title: metric.title,
        series: [
          MetricLineSeries(
            points: _points(sorted, range),
            color: metric.accentColor,
          ),
        ],
        selectedRange: range,
        period: period,
        accentColor: metric.accentColor,
        summaryText: _summary(range, period, view.latest!.text),
        valueFormatter: (value) => view.format(value).text,
      )),
    _padded(HeartStatisticsCard(
      accentColor: metric.accentColor,
      rows: [
        ('Latest', view.latest!.text),
        if (values.isNotEmpty) ...[
          ('Average', view.format(_avg(values)).text),
          ('Lowest', view.format(_min(values)).text),
          ('Highest', view.format(_max(values)).text),
          ('Readings', '${values.length}'),
        ],
        ...view.extraStats,
      ],
    )),
  ];
  return widgets;
}

List<MetricLinePoint> _points(
  List<(DateTime, double)> sorted,
  TimeRange range,
) {
  final base = [
    for (final (time, value) in sorted)
      MetricLinePoint(
        date: instantToLocalDate(time),
        value: value,
        time: time,
      ),
  ];
  return range == TimeRange.day ? base : dailyAverageLinePoints(base);
}

double _heightMetersSquared(double heightCm) {
  final meters = heightCm / 100.0;
  return meters * meters;
}

String _signed(DisplayValue value) {
  final text = value.text;
  return text.startsWith('-') ? text : '+$text';
}

double _avg(Iterable<double> values) {
  final list = values.toList();
  return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
}

double _min(Iterable<double> values) => values.reduce((a, b) => a < b ? a : b);

double _max(Iterable<double> values) => values.reduce((a, b) => a > b ? a : b);

String _summary(TimeRange range, DatePeriod period, String extra) =>
    '${periodTitle(range, period)} · $extra';

Widget _hero(BodyMetric metric, DisplayValue value) => _padded(MetricCard(
      title: metric.title,
      value: value.value,
      unit: value.unit,
      icon: metric.icon,
      accentColor: metric.accentColor,
    ));

Widget _placeholder(BodyMetric metric) => _padded(MetricCardPlaceholder(
      title: metric.title,
      icon: metric.icon,
      accentColor: metric.accentColor,
      message: metric.emptyMessage,
    ));

Widget _padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: child,
    );

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
}
