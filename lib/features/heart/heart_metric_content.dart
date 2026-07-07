import 'package:flutter/material.dart';

import '../../core/period/period_titles.dart';
import '../../core/period/time_range.dart';
import '../../core/presentation/display_value.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../core/time/local_date.dart';
import '../../domain/usecase/load_heart_period_use_case.dart';
import '../../ui/charts/line_chart.dart';
import '../../ui/components/metric_card.dart';
import 'heart_metric.dart';
import 'heart_metric_cards.dart';
import 'heart_metric_notifier.dart';

/// Builds the metric content for a heart/vitals period-detail screen. A trimmed
/// port of the Kotlin per-metric `*Content` functions (`HeartMetricContent.kt`,
/// `HeartVitalDetailContent.kt`, `VitalsBloodPressureContent.kt`), reduced to the
/// primary hero card + period/day line chart + statistics.
List<Widget> heartMetricContent(
  HeartMetric metric,
  HeartMetricState state,
  UnitFormatter formatter,
  DatePeriod period,
) {
  final result = state.result;
  if (result == null) {
    if (state.isLoading) return const [_LoadingBlock()];
    return [_placeholder(metric)];
  }
  switch (metric) {
    case HeartMetric.averageHeartRate:
      return _averageHeartRate(metric, state, result, formatter, period);
    case HeartMetric.restingHeartRate:
      return _restingHeartRate(metric, state, result, formatter, period);
    case HeartMetric.hrv:
      return _hrv(metric, state, result, formatter, period);
    case HeartMetric.bloodPressure:
      return _bloodPressure(metric, state, result, formatter, period);
    case HeartMetric.spo2:
      return _spo2(metric, state, result, formatter, period);
    case HeartMetric.vo2Max:
      return _vo2Max(metric, state, result, formatter, period);
    case HeartMetric.respiratoryRate:
      return _respiratoryRate(metric, state, result, formatter, period);
    case HeartMetric.bodyTemperature:
      return _bodyTemperature(metric, state, result, formatter, period);
    case HeartMetric.bloodGlucose:
      return _bloodGlucose(metric, state, result, formatter, period);
    case HeartMetric.skinTemperature:
      return _skinTemperature(metric, state, result, formatter, period);
  }
}

// ── Heart rate ──────────────────────────────────────────────────────────────

List<Widget> _averageHeartRate(
  HeartMetric metric,
  HeartMetricState state,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
  DatePeriod period,
) {
  final range = state.selectedRange;
  if (range == TimeRange.day) {
    final samples = result.daySamples;
    if (samples.isEmpty) return _emptyOrLoading(metric, state);
    final bpm = samples.map((s) => s.beatsPerMinute.toDouble()).toList();
    final average = _avg(bpm).round();
    return [
      _hero(metric, formatter.heartRate(average), samples.last.source),
      _chart(MetricLineChart(
        title: metric.title,
        series: _singleSeries(
          [for (final s in samples) (s.time, s.beatsPerMinute.toDouble())],
          range,
          metric.accentColor,
          null,
        ),
        selectedRange: range,
        period: period,
        accentColor: metric.accentColor,
        summaryText: _summary(range, period, formatter.heartRate(average).text),
        valueFormatter: (value) => formatter.heartRate(value.round()).text,
      )),
      _stats(metric, [
        ('Average', formatter.heartRate(average).text),
        ('Lowest', formatter.heartRate(_min(bpm).round()).text),
        ('Highest', formatter.heartRate(_max(bpm).round()).text),
        ('Readings', '${samples.length}'),
      ]),
    ];
  }

  final summaries = [...result.dailySummaries]
    ..sort((a, b) => a.date.compareTo(b.date));
  if (summaries.isEmpty) return _emptyOrLoading(metric, state);
  final average = _avg(summaries.map((s) => s.avgBpm.toDouble())).round();
  final lowest = summaries.map((s) => s.minBpm).reduce((a, b) => a < b ? a : b);
  final highest = summaries.map((s) => s.maxBpm).reduce((a, b) => a > b ? a : b);
  final hasRange = summaries.any((s) => s.minBpm != s.maxBpm);
  final series = <MetricLineSeries>[
    MetricLineSeries(
      points: [
        for (final s in summaries)
          MetricLinePoint(date: s.date, value: s.avgBpm.toDouble()),
      ],
      color: metric.accentColor,
      label: 'Average',
    ),
    if (hasRange) ...[
      MetricLineSeries(
        points: [
          for (final s in summaries)
            MetricLinePoint(date: s.date, value: s.minBpm.toDouble()),
        ],
        color: metric.accentColor.withValues(alpha: 0.55),
        label: 'Lowest',
      ),
      MetricLineSeries(
        points: [
          for (final s in summaries)
            MetricLinePoint(date: s.date, value: s.maxBpm.toDouble()),
        ],
        color: metric.accentColor.withValues(alpha: 0.9),
        label: 'Highest',
      ),
    ],
  ];
  return [
    _hero(metric, formatter.heartRate(average), null),
    _chart(MetricLineChart(
      title: metric.title,
      series: series,
      selectedRange: range,
      period: period,
      accentColor: metric.accentColor,
      summaryText: _summary(range, period,
          'avg ${formatter.heartRate(average).text}'),
      valueFormatter: (value) => formatter.heartRate(value.round()).text,
    )),
    _stats(metric, [
      ('Average', formatter.heartRate(average).text),
      ('Lowest', formatter.heartRate(lowest).text),
      ('Highest', formatter.heartRate(highest).text),
      ('Days', '${summaries.length}'),
    ]),
  ];
}

List<Widget> _restingHeartRate(
  HeartMetric metric,
  HeartMetricState state,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
  DatePeriod period,
) {
  final range = state.selectedRange;
  if (range == TimeRange.day) {
    final samples = [...result.dayRestingSamples]
      ..sort((a, b) => a.time.compareTo(b.time));
    final restingBpm = result.dayRestingBpm ??
        (samples.isEmpty
            ? null
            : _avg(samples.map((s) => s.beatsPerMinute.toDouble())).round());
    if (restingBpm == null) return _emptyOrLoading(metric, state);
    return [
      _hero(metric, formatter.heartRate(restingBpm),
          samples.isEmpty ? null : samples.last.source),
      if (samples.length > 1)
        _chart(MetricLineChart(
          title: metric.title,
          series: _singleSeries(
            [for (final s in samples) (s.time, s.beatsPerMinute.toDouble())],
            range,
            metric.accentColor,
            null,
          ),
          selectedRange: range,
          period: period,
          accentColor: metric.accentColor,
          summaryText:
              _summary(range, period, formatter.heartRate(restingBpm).text),
          valueFormatter: (value) => formatter.heartRate(value.round()).text,
        )),
      _stats(metric, [
        ('Resting', formatter.heartRate(restingBpm).text),
        if (samples.isNotEmpty) ...[
          ('Lowest',
              formatter.heartRate(samples.map((s) => s.beatsPerMinute).reduce((a, b) => a < b ? a : b)).text),
          ('Highest',
              formatter.heartRate(samples.map((s) => s.beatsPerMinute).reduce((a, b) => a > b ? a : b)).text),
          ('Readings', '${samples.length}'),
        ],
      ]),
    ];
  }

  final entries = [...result.dailyRestingHR]
    ..sort((a, b) => a.date.compareTo(b.date));
  if (entries.isEmpty) return _emptyOrLoading(metric, state);
  final bpm = entries.map((e) => e.bpm.toDouble()).toList();
  final average = _avg(bpm).round();
  return [
    _hero(metric, formatter.heartRate(average), null),
    _chart(MetricLineChart(
      title: metric.title,
      series: [
        MetricLineSeries(
          points: [
            for (final e in entries)
              MetricLinePoint(date: e.date, value: e.bpm.toDouble()),
          ],
          color: metric.accentColor,
        ),
      ],
      selectedRange: range,
      period: period,
      accentColor: metric.accentColor,
      summaryText: _summary(range, period, formatter.heartRate(average).text),
      valueFormatter: (value) => formatter.heartRate(value.round()).text,
    )),
    _stats(metric, [
      ('Average', formatter.heartRate(average).text),
      ('Lowest', formatter.heartRate(_min(bpm).round()).text),
      ('Highest', formatter.heartRate(_max(bpm).round()).text),
      ('Days', '${entries.length}'),
    ]),
  ];
}

List<Widget> _hrv(
  HeartMetric metric,
  HeartMetricState state,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
  DatePeriod period,
) {
  final range = state.selectedRange;
  if (range == TimeRange.day) {
    final samples = [...result.dayHrvSamples]
      ..sort((a, b) => a.time.compareTo(b.time));
    final hrvMs = result.dayHrvMs ??
        (samples.isEmpty ? null : _avg(samples.map((s) => s.rmssdMs)));
    if (hrvMs == null) return _emptyOrLoading(metric, state);
    return [
      _hero(metric, formatter.hrv(hrvMs),
          samples.isEmpty ? null : samples.last.source),
      if (samples.length > 1)
        _chart(MetricLineChart(
          title: metric.title,
          series: _singleSeries(
            [for (final s in samples) (s.time, s.rmssdMs)],
            range,
            metric.accentColor,
            null,
          ),
          selectedRange: range,
          period: period,
          accentColor: metric.accentColor,
          summaryText: _summary(range, period, formatter.hrv(hrvMs).text),
          valueFormatter: (value) => formatter.hrv(value).text,
        )),
      _stats(metric, [
        ('Average', formatter.hrv(hrvMs).text),
        if (samples.isNotEmpty) ...[
          ('Lowest',
              formatter.hrv(samples.map((s) => s.rmssdMs).reduce((a, b) => a < b ? a : b)).text),
          ('Highest',
              formatter.hrv(samples.map((s) => s.rmssdMs).reduce((a, b) => a > b ? a : b)).text),
          ('Readings', '${samples.length}'),
        ],
      ]),
    ];
  }

  final entries = [...result.dailyHrv]..sort((a, b) => a.date.compareTo(b.date));
  if (entries.isEmpty) return _emptyOrLoading(metric, state);
  final ms = entries.map((e) => e.rmssdMs).toList();
  final average = _avg(ms);
  return [
    _hero(metric, formatter.hrv(average), null),
    _chart(MetricLineChart(
      title: metric.title,
      series: [
        MetricLineSeries(
          points: [
            for (final e in entries)
              MetricLinePoint(date: e.date, value: e.rmssdMs),
          ],
          color: metric.accentColor.withValues(alpha: 0.85),
        ),
      ],
      selectedRange: range,
      period: period,
      accentColor: metric.accentColor,
      summaryText: _summary(range, period, formatter.hrv(average).text),
      valueFormatter: (value) => formatter.hrv(value).text,
    )),
    _stats(metric, [
      ('Average', formatter.hrv(average).text),
      ('Lowest', formatter.hrv(_min(ms)).text),
      ('Highest', formatter.hrv(_max(ms)).text),
      ('Days', '${entries.length}'),
    ]),
  ];
}

// ── Vitals ──────────────────────────────────────────────────────────────────

List<Widget> _bloodPressure(
  HeartMetric metric,
  HeartMetricState state,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
  DatePeriod period,
) {
  final entries = [...result.bloodPressure]
    ..sort((a, b) => a.time.compareTo(b.time));
  if (entries.isEmpty) return _emptyOrLoading(metric, state);
  final latest = entries.last;
  final range = state.selectedRange;
  final systolic = [
    for (final e in entries)
      MetricLinePoint(
          date: instantToLocalDate(e.time),
          value: e.systolicMmHg.toDouble(),
          time: e.time),
  ];
  final diastolic = [
    for (final e in entries)
      MetricLinePoint(
          date: instantToLocalDate(e.time),
          value: e.diastolicMmHg.toDouble(),
          time: e.time),
  ];
  final series = range == TimeRange.day
      ? [
          MetricLineSeries(
              points: systolic, color: metric.accentColor, label: 'Systolic'),
          MetricLineSeries(
              points: diastolic, color: _diastolicColor, label: 'Diastolic'),
        ]
      : [
          MetricLineSeries(
              points: dailyAverageLinePoints(systolic),
              color: metric.accentColor,
              label: 'Systolic'),
          MetricLineSeries(
              points: dailyAverageLinePoints(diastolic),
              color: _diastolicColor,
              label: 'Diastolic'),
        ];
  final avgSys =
      _avg(entries.map((e) => e.systolicMmHg.toDouble())).round();
  final avgDia =
      _avg(entries.map((e) => e.diastolicMmHg.toDouble())).round();
  return [
    _hero(
      metric,
      formatter.bloodPressure(latest.systolicMmHg, latest.diastolicMmHg),
      latest.source,
    ),
    _chart(MetricLineChart(
      title: metric.title,
      series: series,
      selectedRange: range,
      period: period,
      accentColor: metric.accentColor,
      summaryText: _summary(range, period, '${entries.length} readings'),
      valueFormatter: (value) => '${value.round()} mmHg',
    )),
    _stats(metric, [
      ('Average', formatter.bloodPressure(avgSys, avgDia).text),
      ('Latest',
          formatter.bloodPressure(latest.systolicMmHg, latest.diastolicMmHg).text),
      ('Readings', '${entries.length}'),
    ]),
  ];
}

List<Widget> _spo2(
  HeartMetric metric,
  HeartMetricState state,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
  DatePeriod period,
) =>
    _simpleVital(
      metric: metric,
      state: state,
      period: period,
      entries: [
        for (final e in result.spO2) (e.time, e.percent, e.source),
      ],
      format: (v) => formatter.percent(v),
      summaryLabel: (avg) => 'avg ${formatter.percent(avg).text}',
    );

List<Widget> _vo2Max(
  HeartMetric metric,
  HeartMetricState state,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
  DatePeriod period,
) =>
    _simpleVital(
      metric: metric,
      state: state,
      period: period,
      entries: [
        for (final e in result.vo2Max)
          (e.time, e.vo2MaxMlPerKgPerMin, e.source),
      ],
      format: (v) => formatter.vo2Max(v),
      summaryLabel: (avg) => '${result.vo2Max.length} readings',
      requireMultipleForChart: true,
    );

List<Widget> _respiratoryRate(
  HeartMetric metric,
  HeartMetricState state,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
  DatePeriod period,
) =>
    _simpleVital(
      metric: metric,
      state: state,
      period: period,
      entries: [
        for (final e in result.respiratoryRate)
          (e.time, e.breathsPerMinute, e.source),
      ],
      format: (v) => formatter.respiratoryRate(v),
      summaryLabel: (avg) => 'avg ${formatter.respiratoryRate(avg).text}',
    );

List<Widget> _bodyTemperature(
  HeartMetric metric,
  HeartMetricState state,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
  DatePeriod period,
) =>
    _simpleVital(
      metric: metric,
      state: state,
      period: period,
      entries: [
        for (final e in result.bodyTemperature)
          (e.time, e.temperatureCelsius, e.source),
      ],
      format: (v) => formatter.temperature(v),
      summaryLabel: (avg) => '${result.bodyTemperature.length} readings',
    );

List<Widget> _bloodGlucose(
  HeartMetric metric,
  HeartMetricState state,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
  DatePeriod period,
) =>
    _simpleVital(
      metric: metric,
      state: state,
      period: period,
      entries: [
        for (final e in result.bloodGlucose)
          (e.time, e.millimolesPerLiter, e.source),
      ],
      format: (v) => formatter.bloodGlucose(v),
      summaryLabel: (avg) => 'avg ${formatter.bloodGlucose(avg).text}',
    );

List<Widget> _skinTemperature(
  HeartMetric metric,
  HeartMetricState state,
  HeartPeriodLoadResult result,
  UnitFormatter formatter,
  DatePeriod period,
) {
  final entries = result.skinTemperature
      .where((e) => e.averageDeltaCelsius != null)
      .toList();
  if (entries.isEmpty) return _emptyOrLoading(metric, state);
  return _simpleVital(
    metric: metric,
    state: state,
    period: period,
    entries: [
      for (final e in entries) (e.time, e.averageDeltaCelsius!, e.source),
    ],
    format: (v) => formatter.temperatureDelta(v),
    summaryLabel: (avg) => 'avg ${formatter.temperatureDelta(avg).text}',
  );
}

/// Shared builder for the single-value vitals (SpO2 / VO2 / respiratory rate /
/// body & skin temperature / blood glucose): hero latest reading + line chart +
/// average/lowest/highest statistics.
List<Widget> _simpleVital({
  required HeartMetric metric,
  required HeartMetricState state,
  required DatePeriod period,
  required List<(DateTime, double, String)> entries,
  required DisplayValue Function(double) format,
  required String Function(double average) summaryLabel,
  bool requireMultipleForChart = false,
}) {
  if (entries.isEmpty) return _emptyOrLoading(metric, state);
  final range = state.selectedRange;
  final sorted = [...entries]..sort((a, b) => a.$1.compareTo(b.$1));
  final values = sorted.map((e) => e.$2).toList();
  final latest = sorted.last;
  final average = _avg(values);
  final showChart = !requireMultipleForChart || sorted.length > 1;

  return [
    _hero(metric, format(latest.$2), latest.$3),
    if (showChart)
      _chart(MetricLineChart(
        title: metric.title,
        series: _singleSeries(
          [for (final e in sorted) (e.$1, e.$2)],
          range,
          metric.accentColor,
          null,
        ),
        selectedRange: range,
        period: period,
        accentColor: metric.accentColor,
        summaryText: _summary(range, period, summaryLabel(average)),
        valueFormatter: (value) => format(value).text,
      )),
    _stats(metric, [
      ('Average', format(average).text),
      ('Lowest', format(_min(values)).text),
      ('Highest', format(_max(values)).text),
      ('Readings', '${sorted.length}'),
    ]),
  ];
}

// ── Building blocks ───────────────────────────────────────────────────────────

/// Blood-pressure diastolic uses the heart accent, mirroring the Kotlin
/// `bloodPressureSeries` (systolic = VitalsColor, diastolic = HeartColor).
const Color _diastolicColor = Color(0xFFE91E63);

List<MetricLineSeries> _singleSeries(
  List<(DateTime, double)> raw,
  TimeRange range,
  Color color,
  String? label,
) {
  final base = [
    for (final (time, value) in raw)
      MetricLinePoint(date: instantToLocalDate(time), value: value, time: time),
  ];
  final points = range == TimeRange.day ? base : dailyAverageLinePoints(base);
  return [MetricLineSeries(points: points, color: color, label: label)];
}

double _avg(Iterable<double> values) {
  final list = values.toList();
  return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
}

double _min(Iterable<double> values) => values.reduce((a, b) => a < b ? a : b);

double _max(Iterable<double> values) => values.reduce((a, b) => a > b ? a : b);

String _summary(TimeRange range, DatePeriod period, String extra) =>
    '${periodTitle(range, period)} · $extra';

Widget _hero(HeartMetric metric, DisplayValue value, String? source) =>
    _padded(MetricCard(
      title: metric.title,
      value: value.value,
      unit: value.unit,
      icon: metric.icon,
      accentColor: metric.accentColor,
      source: source,
    ));

Widget _stats(HeartMetric metric, List<(String, String)> rows) =>
    _padded(HeartStatisticsCard(rows: rows, accentColor: metric.accentColor));

Widget _chart(Widget chart) => _padded(chart);

Widget _placeholder(HeartMetric metric) => _padded(MetricCardPlaceholder(
      title: metric.title,
      icon: metric.icon,
      accentColor: metric.accentColor,
      message: metric.emptyMessage,
    ));

List<Widget> _emptyOrLoading(HeartMetric metric, HeartMetricState state) =>
    state.isLoading ? const [_LoadingBlock()] : [_placeholder(metric)];

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
