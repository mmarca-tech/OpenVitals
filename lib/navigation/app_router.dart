import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../di/providers.dart';
import '../l10n/app_localizations.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/activity/activities_screen.dart';
import '../features/activity/activity_detail_screen.dart';
import '../features/activity/activity_metric.dart';
import '../features/activity/activity_metric_screen.dart';
import '../features/activity/calories_screen.dart';
import '../features/activity/cardio_load_detail_screen.dart';
import '../features/body/body_metric.dart';
import '../features/body/body_screen.dart';
import '../features/bodyenergy/body_energy_details_screen.dart';
import '../features/caffeine/caffeine_screen.dart';
import '../features/cycle/cycle_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/metric_screen.dart';
import '../features/heart/heart_metric.dart';
import '../features/heart/heart_metric_screen.dart';
import '../features/hydration/hydration_screen.dart';
import '../features/manualentry/activity_entry_screen.dart';
import '../features/manualentry/body_measurement_entry_screen.dart';
import '../features/manualentry/carbs_entry_screen.dart';
import '../features/manualentry/hydration_entry_screen.dart';
import '../features/manualentry/manual_entry_screen.dart';
import '../features/manualentry/mindfulness_entry_screen.dart';
import '../features/manualentry/vitals_measurement_entry_screen.dart';
import '../features/mindfulness/mindfulness_screen.dart';
import '../features/nutrition/nutrition_metric.dart';
import '../features/nutrition/nutrition_metric_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/readiness/daily_readiness_screen.dart';
import '../features/readiness/stress_details_screen.dart';
import '../features/readiness/training_readiness_details_screen.dart';
import '../features/recovery/sleep_efficiency_detail_screen.dart';
import '../features/recovery/sleep_score_detail_screen.dart';
import '../features/settings/ble_devices_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/settings_section.dart';
import '../features/settings/settings_section_screen.dart';
import '../features/sleep/sleep_detail_screen.dart';
import '../features/sleep/sleep_screen.dart';
import '../features/vitals/heart_vitals_overview_screen.dart';
import '../state/app_providers.dart';
import '../ui/components/adaptive_scaffold.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app's [GoRouter], built once and cached by Riverpod so its navigation
/// state survives theme/locale rebuilds of `MaterialApp.router`.
///
/// The start destination mirrors the Kotlin `MainActivity` bootstrap: onboarding
/// unless it has already been completed. (Kotlin additionally gates on Health
/// Connect availability; that async check is deferred to Phase 5 — see the
/// onboarding flow.)
final goRouterProvider = Provider<GoRouter>((ref) {
  final bool onboardingComplete = ref.watch(onboardingCompleteProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation:
        onboardingComplete ? AppRoutes.dashboard : AppRoutes.onboarding,
    routes: _buildRoutes(ref),
  );
});

List<RouteBase> _buildRoutes(Ref ref) => [
      // Full-screen start destination (root navigator, outside the shell).
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => OnboardingScreen(
          onOnboardingComplete: () {
            ref.read(preferencesRepositoryProvider).onboardingDone = true;
            context.go(AppRoutes.dashboard);
          },
        ),
      ),

      // Home: the dashboard, wrapped in the top-bar-only home scaffold. Like the
      // Kotlin app there is NO bottom navigation — every other destination is
      // pushed over this route (with its own back-enabled app bar).
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) =>
            const OpenVitalsHomeScaffold(child: DashboardScreen()),
      ),

      // Top-level sections, now pushed from the top bar / dashboard rather than a
      // bottom nav. ActivitiesScreen brings its own MetricDetailScaffold (app bar
      // + back); the hub + settings screens are wrapped in a titled scaffold.
      GoRoute(
        path: AppRoutes.activity,
        builder: (context, state) => const ActivitiesScreen(),
      ),
      GoRoute(
        path: AppRoutes.manualEntry,
        builder: (context, state) => _titledScreen(
          AppLocalizations.of(context).screenManualEntry,
          const ManualEntryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => _titledScreen(
          AppLocalizations.of(context).screenSettings,
          const SettingsScreen(),
        ),
      ),

      // ── Detail / entry routes pushed over the home route (root navigator) ───
      ..._readinessRoutes(),
      ..._metricSectionRoutes(),
      ..._manualEntryRoutes(),
      ..._settingsSectionRoutes(),
    ];

/// Wraps a self-less screen (no Scaffold of its own) in a titled, back-enabled
/// scaffold so it works as a pushed route.
Widget _titledScreen(String title, Widget child) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );

List<RouteBase> _readinessRoutes() => [
      GoRoute(
        path: AppRoutes.dailyReadiness,
        builder: (context, state) => const DailyReadinessScreen(),
      ),
      GoRoute(
        path: AppRoutes.stressDetails,
        builder: (context, state) => StressDetailsScreen(
          date: state.pathParameters[AppRoutes.stressDateArg]!,
        ),
      ),
      GoRoute(
        path: AppRoutes.bodyEnergyDetails,
        builder: (context, state) => BodyEnergyDetailsScreen(
          date: state.pathParameters[AppRoutes.bodyEnergyDateArg]!,
        ),
      ),
      GoRoute(
        path: AppRoutes.trainingReadinessDetails,
        builder: (context, state) => TrainingReadinessDetailsScreen(
          date: state.pathParameters[AppRoutes.trainingReadinessDateArg]!,
        ),
      ),
    ];

List<RouteBase> _metricSectionRoutes() => [
      GoRoute(
        path: AppRoutes.calories,
        builder: (context, state) => const CaloriesScreen(),
      ),
      GoRoute(
        path: AppRoutes.nutrition,
        builder: (context, state) => const NutritionScreen(),
      ),
      GoRoute(
        path: AppRoutes.body,
        builder: (context, state) => const BodyScreen(),
      ),
      GoRoute(
        path: AppRoutes.heartVitals,
        builder: (context, state) => const HeartVitalsOverviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.cardioLoadDetail,
        builder: (context, state) => const CardioLoadDetailScreen(),
      ),
      GoRoute(
        path: AppRoutes.activityDetail,
        builder: (context, state) => ActivityDetailScreen(
          activityId: state.pathParameters[AppRoutes.activityDetailIdArg]!,
        ),
      ),
      GoRoute(
        path: AppRoutes.sleep,
        builder: (context, state) => const SleepScreen(),
      ),
      GoRoute(
        path: AppRoutes.sleepDetail,
        builder: (context, state) => SleepDetailScreen(
          sleepId: state.pathParameters[AppRoutes.sleepDetailIdArg]!,
        ),
      ),
      GoRoute(
        path: AppRoutes.sleepScoreDetail,
        builder: (context, state) => const SleepScoreDetailScreen(),
      ),
      GoRoute(
        path: AppRoutes.sleepEfficiencyDetail,
        builder: (context, state) => const SleepEfficiencyDetailScreen(),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.metric,
        builder: (context, state) =>
            _metricScreen(state.pathParameters[AppRoutes.metricIdArg]),
      ),
    ];

List<RouteBase> _manualEntryRoutes() => [
      GoRoute(
        path: AppRoutes.hydrationEntry,
        builder: (context, state) => const HydrationEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.hydrationEntryEdit,
        builder: (context, state) => HydrationEntryScreen(
          hydrationEntryId: state.pathParameters[AppRoutes.hydrationEntryIdArg],
        ),
      ),
      GoRoute(
        path: AppRoutes.hydrationEntryLogDrink,
        builder: (context, state) => HydrationEntryScreen(
          logDrinkId: state.pathParameters[AppRoutes.hydrationDrinkIdArg],
        ),
      ),
      GoRoute(
        path: AppRoutes.carbsEntry,
        builder: (context, state) => const CarbsEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.activityEntry,
        builder: (context, state) => ActivityEntryScreen(
          mode: ActivityEntryMode.fromValue(
            state.uri.queryParameters[AppRoutes.activityEntryModeArg],
          ),
          planId: state.uri.queryParameters[AppRoutes.activityEntryPlanIdArg],
          activityTypeId:
              state.uri.queryParameters[AppRoutes.activityEntryTypeArg],
        ),
      ),
      GoRoute(
        path: AppRoutes.activityEntryEdit,
        builder: (context, state) => ActivityEntryScreen(
          activityEntryId: state.pathParameters[AppRoutes.activityEntryIdArg],
        ),
      ),
      GoRoute(
        path: AppRoutes.mindfulnessEntry,
        builder: (context, state) => const MindfulnessEntryScreen(),
      ),
      GoRoute(
        path: AppRoutes.mindfulnessEntryEdit,
        builder: (context, state) => MindfulnessEntryScreen(
          mindfulnessEntryId:
              state.pathParameters[AppRoutes.mindfulnessEntryIdArg],
        ),
      ),
      GoRoute(
        path: AppRoutes.bodyMeasurementEntry,
        builder: (context, state) => BodyMeasurementEntryScreen(
          bodyMeasurementType:
              state.pathParameters[AppRoutes.bodyMeasurementTypeArg]!,
        ),
      ),
      GoRoute(
        path: AppRoutes.bodyMeasurementEntryEdit,
        builder: (context, state) => BodyMeasurementEntryScreen(
          bodyMeasurementType:
              state.pathParameters[AppRoutes.bodyMeasurementTypeArg]!,
          bodyEntryId: state.pathParameters[AppRoutes.bodyEntryIdArg],
        ),
      ),
      GoRoute(
        path: AppRoutes.vitalsMeasurementEntry,
        builder: (context, state) => VitalsMeasurementEntryScreen(
          vitalsMeasurementType:
              state.pathParameters[AppRoutes.vitalsMeasurementTypeArg]!,
        ),
      ),
      GoRoute(
        path: AppRoutes.vitalsMeasurementEntryEdit,
        builder: (context, state) => VitalsMeasurementEntryScreen(
          vitalsMeasurementType:
              state.pathParameters[AppRoutes.vitalsMeasurementTypeArg]!,
          vitalsEntryId: state.pathParameters[AppRoutes.vitalsEntryIdArg],
        ),
      ),
    ];

/// One pushed route per [SettingsSection] (Display, Activities, Sensors,
/// Nutrition, Recovery, Data import, Health Connect). The BLE Sensors and Data
/// Import sections configure Phase-6 subsystems and render a "coming soon" body.
List<RouteBase> _settingsSectionRoutes() => [
      for (final section in SettingsSection.values)
        GoRoute(
          path: section.route,
          builder: (context, state) => section == SettingsSection.sensors
              ? const BleDevicesScreen()
              : SettingsSectionScreen(section: section),
        ),
    ];

// Metric-id classification, mirroring the Kotlin `MetricRouteContent` dispatch.
// (The ten heart + vitals ids are classified by [HeartMetric.fromRouteName].)
const Set<DashboardMetricId> _nutritionMetrics = {
  DashboardMetricId.caloriesIn,
  DashboardMetricId.protein,
  DashboardMetricId.carbs,
  DashboardMetricId.fat,
};
const Set<DashboardMetricId> _bodyMetrics = {
  DashboardMetricId.weight,
  DashboardMetricId.height,
  DashboardMetricId.bmi,
  DashboardMetricId.ffmi,
  DashboardMetricId.bodyFat,
  DashboardMetricId.leanMass,
  DashboardMetricId.boneMass,
  DashboardMetricId.bodyWaterMass,
};
const Set<DashboardMetricId> _caloriesMetrics = {
  DashboardMetricId.caloriesOut,
  DashboardMetricId.activeCalories,
  DashboardMetricId.bmr,
};
const Set<DashboardMetricId> _cardioMetrics = {
  DashboardMetricId.weeklyCardioLoad,
  DashboardMetricId.cardioLoad,
};

/// Routes `/metric/:metricId` to the matching feature placeholder, falling back
/// to the generic [MetricScreen] for uncategorised metric ids.
Widget _metricScreen(String? raw) {
  final id = DashboardMetricId.fromStorage(raw);
  if (id == null) return MetricScreen(metricId: raw);
  // The six movement metrics (steps/distance/calories-out/active-calories/
  // floors/elevation/wheelchair) share the parametric activity detail screen.
  final activityMetric = ActivityMetric.fromRouteName(raw);
  if (activityMetric != null) {
    return ActivityMetricScreen(metric: activityMetric);
  }
  // The ten heart + vitals metrics (avg/resting HR, HRV, blood pressure, SpO2,
  // VO2 max, respiratory rate, body/skin temperature, blood glucose) share the
  // parametric heart/vitals detail screen (Kotlin `MetricRouteContent`).
  final heartMetric = HeartMetric.fromRouteName(raw);
  if (heartMetric != null) return HeartMetricScreen(metric: heartMetric);
  // The nine body-composition metrics (weight/height/BMI/FFMI/body-fat/lean
  // mass/BMR/bone mass/body-water mass) share the parametric body detail screen
  // (Kotlin `toBodyMetricOrNull`); this also claims BMR from `_caloriesMetrics`.
  final bodyMetric = BodyMetric.fromRouteName(raw);
  if (bodyMetric != null) return BodyMetricScreen(metric: bodyMetric);
  // The four keyed nutrition metrics (calories-in / protein / carbs / fat)
  // share the parametric nutrition metric-detail screen (Kotlin
  // `NutritionMetricScreen`); the overview lives on the `/nutrition` route.
  final nutritionMetric = NutritionMetric.fromRouteName(raw);
  if (nutritionMetric != null) {
    return NutritionMetricScreen(metric: nutritionMetric);
  }
  if (_nutritionMetrics.contains(id)) return const NutritionScreen();
  if (_bodyMetrics.contains(id)) return const BodyScreen();
  if (_caloriesMetrics.contains(id)) return const CaloriesScreen();
  if (_cardioMetrics.contains(id)) return const CardioLoadDetailScreen();
  switch (id) {
    case DashboardMetricId.caffeine:
      return const CaffeineScreen();
    case DashboardMetricId.cycle:
      return const CycleScreen();
    case DashboardMetricId.hydration:
      return const HydrationScreen();
    case DashboardMetricId.mindfulness:
      return const MindfulnessScreen();
    case DashboardMetricId.sleep:
      return const SleepScreen();
    default:
      return MetricScreen(metricId: raw);
  }
}
