import 'package:flutter/material.dart';

import '../../core/presentation/unit_formatter.dart';
import '../../domain/insights/sleep_score.dart';
import '../../domain/model/dashboard_data.dart';
import '../../domain/model/dashboard_query.dart';
import '../../navigation/app_routes.dart';
import '../../ui/components/metric_card.dart';
import '../../ui/theme/app_colors.dart';

/// The grouped summary cards below the day navigator. Each [DashboardMetric] is
/// rendered as a [MetricCard] (or a [MetricCardPlaceholder] while it is still
/// loading in the background pass / has no data), and taps through to its
/// concrete detail route via [onOpenMetric]. A feature-local widget: the card
/// chrome + value formatting for the dashboard lives here rather than in the
/// shared shell.
class DashboardMetricSections extends StatelessWidget {
  const DashboardMetricSections({
    super.key,
    required this.data,
    required this.formatter,
    required this.loadingMetrics,
    required this.onOpenMetric,
  });

  final DashboardData data;
  final UnitFormatter formatter;
  final Set<DashboardMetric> loadingMetrics;

  /// Invoked with the go_router location for the tapped metric's detail route.
  final void Function(String location) onOpenMetric;

  static const List<(String, List<DashboardMetric>)> _sections = [
    (
      'Activity',
      [
        DashboardMetric.steps,
        DashboardMetric.distance,
        DashboardMetric.caloriesOut,
        DashboardMetric.floors,
      ],
    ),
    (
      'Sleep & recovery',
      [
        DashboardMetric.sleep,
        DashboardMetric.hrv,
        DashboardMetric.restingHeartRate,
      ],
    ),
    (
      'Heart & vitals',
      [
        DashboardMetric.avgHeartRate,
        DashboardMetric.bloodPressure,
        DashboardMetric.spo2,
      ],
    ),
    (
      'Body',
      [
        DashboardMetric.weight,
        DashboardMetric.bodyFat,
        DashboardMetric.bmi,
      ],
    ),
    (
      'Nutrition & hydration',
      [
        DashboardMetric.caloriesIn,
        DashboardMetric.protein,
        DashboardMetric.hydration,
        DashboardMetric.caffeine,
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, metrics) in _sections) ...[
          SectionHeader(title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 640 ? 3 : 2;
                return _MetricGrid(
                  columns: columns,
                  cards: [for (final metric in metrics) _card(metric)],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _card(DashboardMetric metric) {
    final chrome = _metricChrome(metric);
    void onTap() => onOpenMetric(_locationFor(metric));
    if (loadingMetrics.contains(metric)) {
      return MetricCardPlaceholder(
        title: chrome.title,
        icon: chrome.icon,
        accentColor: chrome.color,
        message: 'Loading…',
        onTap: onTap,
      );
    }
    final value = _metricValue(metric, data, formatter);
    if (value == null) {
      return MetricCardPlaceholder(
        title: chrome.title,
        icon: chrome.icon,
        accentColor: chrome.color,
        message: 'No data',
        onTap: onTap,
      );
    }
    return MetricCard(
      title: chrome.title,
      value: value.value,
      unit: value.unit,
      icon: chrome.icon,
      accentColor: chrome.color,
      subtitle: value.subtitle,
      onTap: onTap,
    );
  }
}

/// Lays out [cards] in fixed-width rows of [columns], padding the final row so
/// every card keeps a uniform width.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.columns, required this.cards});

  final int columns;
  final List<Widget> cards;

  static const double _spacing = 12;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += columns) {
      final rowCards = cards.sublist(
        i,
        (i + columns).clamp(0, cards.length),
      );
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + columns < cards.length ? _spacing : 0),
          // IntrinsicHeight bounds the row's height so stretched cards in the
          // same row share a uniform height instead of forcing infinity.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: _spacing),
                  Expanded(
                    child: c < rowCards.length
                        ? rowCards[c]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

typedef _MetricChrome = ({String title, IconData icon, Color color});
typedef _MetricValue = ({String value, String unit, String? subtitle});

_MetricChrome _metricChrome(DashboardMetric metric) {
  switch (metric) {
    case DashboardMetric.steps:
      return (title: 'Steps', icon: Icons.directions_walk, color: AppColors.steps);
    case DashboardMetric.distance:
      return (title: 'Distance', icon: Icons.straighten, color: AppColors.distance);
    case DashboardMetric.caloriesOut:
      return (
        title: 'Calories',
        icon: Icons.local_fire_department,
        color: AppColors.calories,
      );
    case DashboardMetric.floors:
      return (title: 'Floors', icon: Icons.stairs, color: AppColors.floors);
    case DashboardMetric.sleep:
      return (title: 'Sleep', icon: Icons.bedtime, color: AppColors.sleep);
    case DashboardMetric.hrv:
      return (title: 'HRV', icon: Icons.monitor_heart, color: AppColors.heart);
    case DashboardMetric.restingHeartRate:
      return (title: 'Resting HR', icon: Icons.favorite, color: AppColors.heart);
    case DashboardMetric.avgHeartRate:
      return (
        title: 'Heart rate',
        icon: Icons.favorite_border,
        color: AppColors.heart,
      );
    case DashboardMetric.bloodPressure:
      return (
        title: 'Blood pressure',
        icon: Icons.bloodtype,
        color: AppColors.vitals,
      );
    case DashboardMetric.spo2:
      return (title: 'Blood oxygen', icon: Icons.air, color: AppColors.vitals);
    case DashboardMetric.weight:
      return (title: 'Weight', icon: Icons.monitor_weight, color: AppColors.weight);
    case DashboardMetric.bodyFat:
      return (title: 'Body fat', icon: Icons.pie_chart, color: AppColors.bodyFat);
    case DashboardMetric.bmi:
      return (title: 'BMI', icon: Icons.accessibility_new, color: AppColors.weight);
    case DashboardMetric.caloriesIn:
      return (
        title: 'Calories in',
        icon: Icons.restaurant,
        color: AppColors.nutrition,
      );
    case DashboardMetric.protein:
      return (title: 'Protein', icon: Icons.egg_alt, color: AppColors.nutrition);
    case DashboardMetric.hydration:
      return (
        title: 'Hydration',
        icon: Icons.water_drop,
        color: AppColors.hydration,
      );
    case DashboardMetric.caffeine:
      return (title: 'Caffeine', icon: Icons.coffee, color: AppColors.nutrition);
    // Metrics not surfaced as summary cards fall back to a neutral chrome.
    default:
      return (title: metric.storageName, icon: Icons.insights, color: AppColors.heart);
  }
}

/// The go_router location for [metric]'s detail route. Metrics with a dedicated
/// top-level section route go straight there; the rest ride the generic
/// `/metric/:metricId` route, which the router dispatches to the matching
/// feature screen (Kotlin `MetricRouteContent`).
String _locationFor(DashboardMetric metric) {
  switch (metric) {
    case DashboardMetric.sleep:
      return AppRoutes.sleep;
    case DashboardMetric.caloriesOut:
      return AppRoutes.calories;
    case DashboardMetric.caloriesIn:
    case DashboardMetric.protein:
      return AppRoutes.nutrition;
    case DashboardMetric.weight:
    case DashboardMetric.bodyFat:
    case DashboardMetric.bmi:
      return AppRoutes.body;
    default:
      return AppRoutes.metricLocation(metric.storageName);
  }
}

_MetricValue? _metricValue(
  DashboardMetric metric,
  DashboardData d,
  UnitFormatter f,
) {
  switch (metric) {
    case DashboardMetric.steps:
      if (d.steps <= 0) return null;
      return (value: f.count(d.steps), unit: 'steps', subtitle: null);
    case DashboardMetric.distance:
      if (d.distanceMeters <= 0) return null;
      final dv = f.distance(d.distanceMeters);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.caloriesOut:
      if (d.caloriesKcal <= 0) return null;
      final dv = f.energy(d.caloriesKcal);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.floors:
      final floors = d.floorsClimbed;
      if (floors == null || floors <= 0) return null;
      return (value: f.count(floors), unit: 'floors', subtitle: null);
    case DashboardMetric.sleep:
      final sleep = d.sleep;
      if (sleep == null) return null;
      final score = d.sleepScore;
      final subtitle = score.confidence != SleepScoreConfidence.noData
          ? 'Score ${score.score}'
          : null;
      return (value: f.duration(sleep.durationMs), unit: '', subtitle: subtitle);
    case DashboardMetric.hrv:
      final hrv = d.hrvRmssdMs;
      if (hrv == null || hrv <= 0) return null;
      final dv = f.hrv(hrv);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.restingHeartRate:
      if (d.restingHeartRateBpm <= 0) return null;
      final dv = f.heartRate(d.restingHeartRateBpm);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.avgHeartRate:
      if (d.avgHeartRateBpm <= 0) return null;
      final dv = f.heartRate(d.avgHeartRateBpm);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.bloodPressure:
      final sys = d.latestSystolicMmHg;
      final dia = d.latestDiastolicMmHg;
      if (sys == null || dia == null) return null;
      final dv = f.bloodPressure(sys, dia);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.spo2:
      final spo2 = d.latestSpO2Percent;
      if (spo2 == null) return null;
      final dv = f.percent(spo2);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.weight:
      final w = d.weightKg;
      if (w == null || w <= 0) return null;
      final dv = f.weight(w);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.bodyFat:
      if (d.bodyFatPercent <= 0) return null;
      final dv = f.percent(d.bodyFatPercent);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.bmi:
      final bmi = d.bmi;
      if (bmi == null || bmi <= 0) return null;
      return (value: f.decimal(bmi, 1), unit: '', subtitle: null);
    case DashboardMetric.caloriesIn:
      final kcal = d.caloriesInKcal;
      if (kcal == null || kcal <= 0) return null;
      final dv = f.energy(kcal);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.protein:
      final p = d.proteinGrams;
      if (p == null || p <= 0) return null;
      return (value: f.decimal(p, 0), unit: 'g', subtitle: null);
    case DashboardMetric.hydration:
      if (d.hydrationLiters <= 0) return null;
      final dv = f.hydration(d.hydrationLiters);
      return (value: dv.value, unit: dv.unit, subtitle: null);
    case DashboardMetric.caffeine:
      final caffeine = d.caffeineGrams;
      if (caffeine == null || caffeine <= 0) return null;
      return (value: f.decimal(caffeine * 1000, 0), unit: 'mg', subtitle: null);
    default:
      return null;
  }
}
