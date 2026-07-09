import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/core/presentation/unit_formatter.dart';
import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/domain/model/dashboard_data.dart';
import 'package:openvitals/domain/model/dashboard_query.dart';
import 'package:openvitals/domain/preferences/unit_system.dart';
import 'package:openvitals/features/dashboard/dashboard_summary_presentation.dart';
import 'package:openvitals/l10n/app_localizations.dart';

/// Builds the summary for [supported], with no readings for any metric beyond
/// the handful the fixture sets.
DashboardSummary _summaryFor(
  Set<DashboardMetric> supported,
  AppLocalizations l10n, {
  double? spo2,
}) =>
    buildDashboardSummary(
      DashboardData(
        date: LocalDate(2026, 1, 2),
        latestSpO2Percent: spo2,
        supportedMetrics: supported,
      ),
      UnitFormatter(unitSystemProvider: () => UnitSystem.metric),
      l10n,
    );

List<String> _titles(DashboardSummary s) => [for (final t in s.tiles) t.title];

StatTileData _tile(DashboardSummary s, String title) =>
    s.tiles.firstWhere((t) => t.title == title);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('a supported metric with no reading still gets an empty tile', () {
    final summary = _summaryFor({DashboardMetric.spo2}, l10n);

    expect(_titles(summary), contains('Blood oxygen'));
    final tile = _tile(summary, 'Blood oxygen');
    // Empty: the no-data message replaces the value, and no unit/progress trails.
    expect(tile.message, l10n.messageNoOxygen);
    expect(tile.value, isEmpty);
    expect(tile.unit, isNull);
    expect(tile.progress, isNull);
  });

  test('a supported metric with a reading renders its value, not a message', () {
    final summary = _summaryFor({DashboardMetric.spo2}, l10n, spo2: 97);

    final tile = _tile(summary, 'Blood oxygen');
    expect(tile.message, isNull);
    expect(tile.value, isNotEmpty);
  });

  test('an unsupported metric gets no tile at all', () {
    // Everything except blood oxygen.
    final supported = DashboardMetric.values.toSet()
      ..remove(DashboardMetric.spo2);
    final summary = _summaryFor(supported, l10n);

    expect(_titles(summary), isNot(contains('Blood oxygen')));
    // …but its supported neighbours are still there, empty.
    expect(_titles(summary), contains('VO₂ max'));
    expect(_tile(summary, 'VO₂ max').message, l10n.messageNoVo2Max);
  });

  test('required metrics show a zero reading rather than a no-data message', () {
    final summary = _summaryFor({
      DashboardMetric.distance,
      DashboardMetric.hydration,
      DashboardMetric.bodyFat,
      DashboardMetric.avgHeartRate,
      DashboardMetric.restingHeartRate,
      DashboardMetric.mindfulness,
    }, l10n);

    expect(summary.tiles, hasLength(6));
    for (final tile in summary.tiles) {
      expect(tile.message, isNull, reason: '${tile.title} should show its zero');
      expect(tile.value, isNotEmpty, reason: '${tile.title} needs a value');
    }
  });

  test('metrics the mapper previously dropped now appear when supported', () {
    // These had no tile in the mapper at all before device-support gating.
    final summary = _summaryFor(DashboardMetric.values.toSet(), l10n);
    expect(
      _titles(summary),
      containsAll(<String>[
        'Blood glucose',
        'Skin temperature',
        'BMR',
        'Bone mass',
        'Body water',
        'Cycle',
      ]),
    );
  });

  test('no tiles at all when the device supports nothing', () {
    expect(_summaryFor(const <DashboardMetric>{}, l10n).tiles, isEmpty);
  });
}
