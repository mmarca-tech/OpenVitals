import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../di/providers.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/activity/activities_screen.dart';
import '../features/activity/activity_detail_screen.dart';
import '../features/activity/activity_metric.dart';
import '../features/activity/activity_metric_screen.dart';
import '../features/activity/calories_screen.dart';
import '../features/activity/cardio_load_detail_screen.dart';
import '../features/body/body_screen.dart';
import '../features/bodyenergy/body_energy_details_screen.dart';
import '../features/caffeine/caffeine_screen.dart';
import '../features/cycle/cycle_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/metric_screen.dart';
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
import '../features/nutrition/nutrition_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/readiness/daily_readiness_screen.dart';
import '../features/readiness/stress_details_screen.dart';
import '../features/readiness/training_readiness_details_screen.dart';
import '../features/recovery/sleep_efficiency_detail_screen.dart';
import '../features/recovery/sleep_score_detail_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/settings_section_screen.dart';
import '../features/sleep/sleep_detail_screen.dart';
import '../features/sleep/sleep_screen.dart';
import '../features/vitals/heart_vitals_overview_screen.dart';
import '../state/app_providers.dart';
import '../ui/components/adaptive_scaffold.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _dashboardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final _activityNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'activity');
final _addEntryNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'addEntry');
final _settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

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

      // Top-level nav-suite destinations rendered inside the adaptive scaffold.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            OpenVitalsAdaptiveScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _dashboardNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _activityNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.activity,
                builder: (context, state) => const ActivitiesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _addEntryNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.manualEntry,
                builder: (context, state) => const ManualEntryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Detail / entry routes pushed over the shell (root navigator) ────────
      ..._readinessRoutes(),
      ..._metricSectionRoutes(),
      ..._manualEntryRoutes(),
      ..._settingsSectionRoutes(),
    ];

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

List<RouteBase> _settingsSectionRoutes() {
  RouteBase section(String path, String title) => GoRoute(
        path: path,
        builder: (context, state) => SettingsSectionScreen(title: title),
      );
  return [
    section(AppRoutes.settingsDisplay, 'Display'),
    section(AppRoutes.settingsActivities, 'Activities'),
    section(AppRoutes.settingsSensors, 'Sensors'),
    section(AppRoutes.settingsNutrition, 'Nutrition'),
    section(AppRoutes.settingsCalories, 'Calories'),
    section(AppRoutes.settingsCaffeine, 'Caffeine'),
    section(AppRoutes.settingsRecovery, 'Recovery'),
    section(AppRoutes.settingsSleep, 'Sleep'),
    section(AppRoutes.settingsBodyEnergy, 'Body energy'),
    section(AppRoutes.settingsDataImport, 'Data import'),
    section(AppRoutes.settingsHealthConnect, 'Health Connect'),
    section(AppRoutes.settingsPermissions, 'Permissions'),
    section(AppRoutes.settingsDebugDiagnostics, 'Diagnostics'),
  ];
}

// Metric-id classification, mirroring the Kotlin `MetricRouteContent` dispatch.
const Set<DashboardMetricId> _heartMetrics = {
  DashboardMetricId.avgHeartRate,
  DashboardMetricId.restingHeartRate,
  DashboardMetricId.hrv,
  DashboardMetricId.bloodPressure,
  DashboardMetricId.spo2,
  DashboardMetricId.vo2Max,
  DashboardMetricId.respiratoryRate,
  DashboardMetricId.bodyTemperature,
  DashboardMetricId.bloodGlucose,
  DashboardMetricId.skinTemperature,
};
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
  if (_heartMetrics.contains(id)) return HeartMetricScreen(metricId: raw!);
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
