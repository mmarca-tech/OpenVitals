import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/presentation/unit_formatter.dart';
import '../../core/time/local_date.dart';
import '../../domain/insights/daily_goals.dart';
import '../../domain/insights/daily_readiness.dart';
import '../../domain/model/dashboard_data.dart';
import '../../domain/model/dashboard_query.dart';
import '../../domain/model/refresh_mode.dart';
import '../../data/prefs/preferences_repository.dart';
import '../../domain/preferences/activity_week_mode.dart';
import '../../domain/preferences/sleep_range_mode.dart';
import '../../domain/usecase/load_dashboard_day_use_case.dart';
import '../../l10n/app_localizations.dart';
import 'home_widget_service.dart';
import 'home_widget_snapshots.dart';

/// Loads today's dashboard once and pushes every placed home-screen widget.
///
/// The Kotlin side has no equivalent: there, each `GlanceAppWidget` loads its own
/// data on `onUpdate` (through a Hilt entry point) and renders it. Here the data
/// lives in Dart, so one load fans out to all the widgets — which is also why the
/// refresher, not the widget, decides *when* data is stale (see
/// `home_widget_alarm.dart` for the periodic path and `DashboardNotifier._publish`
/// for the foreground one).
///
/// Nothing here may throw: it runs fire-and-forget from the UI and from an alarm
/// isolate, where an escaping exception kills the alarm service and Android never
/// retries. Every step is individually guarded, so one failing widget cannot stop
/// the others from updating.
class HomeWidgetRefresher {
  const HomeWidgetRefresher({
    required this.service,
    required this.loadDashboardDay,
    required this.unitFormatter,
    required this.localizations,
    required this.goals,
    this.sleepRangeMode,
    this.activityWeekMode,
  });

  final HomeWidgetService service;
  final LoadDashboardDayUseCase loadDashboardDay;
  final UnitFormatter unitFormatter;
  final AppLocalizations localizations;
  final DailyReadinessGoalInputs goals;

  /// Preference-driven query inputs (the Kotlin widget loaders read the same two
  /// off `PreferencesRepository`). Null falls back to the [DashboardQuery]
  /// defaults.
  final SleepRangeMode? sleepRangeMode;
  final ActivityWeekMode? activityWeekMode;

  /// Loads today and pushes every widget.
  Future<void> refresh() async {
    try {
      final data = await loadDashboardDay(_todayQuery());
      await push(data);
    } catch (error, stack) {
      debugPrint('Home widget refresh failed: $error\n$stack');
    }
  }

  /// Pushes [data] to every widget, without loading anything.
  ///
  /// The dashboard already holds a fully-merged [DashboardData] for today, so it
  /// hands it straight over rather than paying for a second read.
  Future<void> push(DashboardData data) async {
    await _guard('daily readiness', () async {
      await service.pushSnapshot(
        HomeWidgetId.dailyReadiness,
        buildDailyReadinessSnapshot(data, localizations, goals: goals),
      );
    });
    await _guard('body energy', () async {
      await service.pushSnapshot(
        HomeWidgetId.bodyEnergy,
        buildBodyEnergySnapshot(data, localizations),
      );
    });
    await _guard('today vitals', () async {
      await service.pushSnapshot(
        HomeWidgetId.todayVitals,
        buildTodayVitalsSnapshot(data, unitFormatter, localizations,
            goals: goals),
      );
    });
    await _guard('metric widgets', () => _pushMetricWidgets(data));
    // Extension point: the quick-beverage widgets (HomeWidgetId.quickBeverage /
    // quickBeverageOneTap) push their configured drink here, once the beverage
    // phase lands. They are per-instance like the metric widget, so they follow
    // the same instancesOf → selectionIdOf → pushSnapshot shape — but they read
    // the drink catalog from drift, which the alarm isolate deliberately does
    // not open (see home_widget_alarm.dart).
  }

  /// One push per *placed* metric tile, each showing the metric that instance was
  /// configured with (Kotlin `refreshHomeMetricWidget` per `appWidgetId`).
  Future<void> _pushMetricWidgets(DashboardData data) async {
    final instances = await service.instancesOf(HomeWidgetId.metric);
    for (final instance in instances) {
      final selectionId = await service.selectionIdOf(
        HomeWidgetId.metric,
        appWidgetId: instance.appWidgetId,
      );
      final metric =
          selectionId == null ? null : DashboardMetric.fromStorage(selectionId);
      // An unconfigured (or unknown) instance keeps its native "Select a metric"
      // state: pushing a snapshot over it would claim it is configured.
      if (metric == null) continue;
      await service.pushSnapshot(
        HomeWidgetId.metric,
        buildMetricSnapshot(metric, data, unitFormatter, localizations),
        appWidgetId: instance.appWidgetId,
        selectionId: metric.storageName,
      );
    }
  }

  /// Today, with every metric — the widgets between them cover most of the
  /// catalog, and the readiness/body-energy snapshots need the baselines and
  /// weekly training signals.
  DashboardQuery _todayQuery() => DashboardQuery(
        date: LocalDate.now(),
        sleepRangeMode: sleepRangeMode ?? SleepRangeMode.evening18h,
        activityWeekMode: activityWeekMode ?? ActivityWeekMode.mondayToSunday,
        refreshMode: RefreshMode.force,
      );

  Future<void> _guard(String label, Future<void> Function() step) async {
    try {
      await step();
    } catch (error, stack) {
      debugPrint('Home widget push ($label) failed: $error\n$stack');
    }
  }
}

/// The readiness goal inputs, from the user's daily goals (Kotlin
/// `PreferencesRepository.homeReadinessGoals()`).
DailyReadinessGoalInputs homeWidgetReadinessGoals(
  PreferencesRepository preferences,
) =>
    DailyReadinessGoalInputs(
      stepsGoal: preferences.dailyGoalFor(MetricDailyGoalKey.steps),
      hydrationLitersGoal: preferences.hydrationDailyGoalLiters,
      activeMinutesGoal:
          preferences.dailyGoalFor(MetricDailyGoalKey.activeCaloriesKcal) / 10.0,
    );

/// The device locale's localizations, for the snapshot builders — which run both
/// from the UI and from the alarm isolate, where no `BuildContext` exists (the
/// same lookup the recording controller does for its notification texts).
AppLocalizations homeWidgetLocalizations() {
  try {
    return lookupAppLocalizations(PlatformDispatcher.instance.locale);
  } on FlutterError {
    return lookupAppLocalizations(const Locale('en'));
  }
}
