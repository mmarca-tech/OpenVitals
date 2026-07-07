import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/beverage/beverage_store.dart';
import '../data/local/open_vitals_database.dart';
import '../data/prefs/preferences_repository.dart';
import '../data/repository/body_energy_timeline_cache_store.dart';
import '../data/repository/contract/activity_repository.dart';
import '../data/repository/contract/apple_health_import_repository.dart';
import '../data/repository/contract/ble_device_repository.dart';
import '../data/repository/contract/body_energy_repository.dart';
import '../data/repository/contract/body_repository.dart';
import '../data/repository/contract/caffeine_repository.dart';
import '../data/repository/contract/cycle_repository.dart';
import '../data/repository/contract/health_repository.dart';
import '../data/repository/contract/heart_repository.dart';
import '../data/repository/contract/hydration_repository.dart';
import '../data/repository/contract/mindfulness_repository.dart';
import '../data/repository/contract/nutrition_repository.dart';
import '../data/repository/contract/sleep_repository.dart';
import '../data/repository/contract/vitals_repository.dart';
import '../data/repository/dashboard/dashboard_data_loader.dart';
import '../data/repository/impl/activity_marker_repository_impl.dart';
import '../data/repository/impl/activity_repository_impl.dart';
import '../data/repository/impl/apple_health_import_repository_impl.dart';
import '../data/repository/impl/ble_device_repository_impl.dart';
import '../data/repository/impl/body_energy_repository_impl.dart';
import '../data/repository/impl/body_repository_impl.dart';
import '../data/repository/impl/caffeine_repository_impl.dart';
import '../data/repository/impl/cycle_repository_impl.dart';
import '../data/repository/impl/health_repository_impl.dart';
import '../data/repository/impl/heart_repository_impl.dart';
import '../data/repository/impl/hydration_repository_impl.dart';
import '../data/repository/impl/mindfulness_repository_impl.dart';
import '../data/repository/impl/nutrition_repository_impl.dart';
import '../data/repository/impl/sleep_repository_impl.dart';
import '../data/repository/impl/vitals_repository_impl.dart';
import '../domain/usecase/load_dashboard_day_use_case.dart';
import '../features/imports/applehealth/apple_health_import_report_store.dart';
import '../features/imports/applehealth/apple_health_import_service.dart';
import '../domain/usecase/load_heart_period_use_case.dart';
import '../domain/usecase/load_sleep_period_use_case.dart';
import '../features/activity/maps/offline_map_import_controller.dart';
import '../features/activity/maps/offline_map_metadata_store.dart';
import '../features/homewidgets/home_widget_service.dart';
import '../features/hydration/reminders/hydration_reminder_controller.dart';
import '../features/hydration/reminders/hydration_reminder_device.dart';
import '../features/mindfulness/reminders/mindfulness_reminder_controller.dart';
import '../features/mindfulness/reminders/mindfulness_reminder_device.dart';
import '../health/health_data_source.dart';
import '../health/health_data_source_impl.dart';

/// Riverpod DI graph, replacing the Hilt `AppModule` / `RepositoryModule`.
///
/// [sharedPreferencesProvider] must be overridden at app startup with a resolved
/// [SharedPreferences] instance (the standard Riverpod bootstrap pattern), e.g.:
///
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// runApp(ProviderScope(
///   overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
///   child: const App(),
/// ));
/// ```

/// OpenVitals app package/bundle id, used for OpenVitals-record ownership
/// tagging (mirrors the Kotlin `context.packageName`).
const String openVitalsPackageName = 'tech.mmarca.openvitals';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden at app startup',
  ),
);

QueryExecutor _openDatabaseConnection() => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'openvitals.db'));
      return NativeDatabase.createInBackground(file);
    });

final openVitalsDatabaseProvider = Provider<OpenVitalsDatabase>((ref) {
  final db = OpenVitalsDatabase(_openDatabaseConnection());
  ref.onDispose(db.close);
  return db;
});

final beverageDaoProvider = Provider<BeverageDao>(
  (ref) => ref.watch(openVitalsDatabaseProvider).beverageDao,
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(sharedPreferencesProvider)),
);

final beverageStoreProvider = Provider<BeverageStore>(
  (ref) => BeverageStore(
    ref.watch(beverageDaoProvider),
    ref.watch(preferencesRepositoryProvider),
  ),
);

final bodyEnergyTimelineCacheStoreProvider =
    Provider<BodyEnergyTimelineCacheStore>(
  (ref) => BodyEnergyTimelineCacheStore(ref.watch(sharedPreferencesProvider)),
);

final healthDataSourceProvider = Provider<HealthDataSource>(
  (ref) => HealthDataSourceImpl(appPackageName: openVitalsPackageName),
);

// ── Repositories (contract → impl) ────────────────────────────────────────

final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepositoryImpl(ref.watch(healthDataSourceProvider)),
);

final heartRepositoryProvider = Provider<HeartRepository>(
  (ref) => HeartRepositoryImpl(ref.watch(healthDataSourceProvider)),
);

final sleepRepositoryProvider = Provider<SleepRepository>(
  (ref) => SleepRepositoryImpl(ref.watch(healthDataSourceProvider)),
);

final bodyRepositoryProvider = Provider<BodyRepository>(
  (ref) => BodyRepositoryImpl(ref.watch(healthDataSourceProvider)),
);

final vitalsRepositoryProvider = Provider<VitalsRepository>(
  (ref) => VitalsRepositoryImpl(ref.watch(healthDataSourceProvider)),
);

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => NutritionRepositoryImpl(ref.watch(healthDataSourceProvider)),
);

final caffeineRepositoryProvider = Provider<CaffeineRepository>(
  (ref) => CaffeineRepositoryImpl(ref.watch(nutritionRepositoryProvider)),
);

final mindfulnessRepositoryProvider = Provider<MindfulnessRepository>(
  (ref) => MindfulnessRepositoryImpl(ref.watch(healthDataSourceProvider)),
);

final cycleRepositoryProvider = Provider<CycleRepository>(
  (ref) => CycleRepositoryImpl(ref.watch(healthDataSourceProvider)),
);

final activityMarkerRepositoryProvider = Provider<ActivityMarkerRepository>(
  (ref) => ActivityMarkerRepositoryImpl(ref.watch(sharedPreferencesProvider)),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepositoryImpl(
    ref.watch(healthDataSourceProvider),
    preferencesRepository: ref.watch(preferencesRepositoryProvider),
    markerRepository: ref.watch(activityMarkerRepositoryProvider),
  ),
);

final hydrationRepositoryProvider = Provider<HydrationRepository>(
  (ref) => HydrationRepositoryImpl(
    ref.watch(healthDataSourceProvider),
    preferencesRepository: ref.watch(preferencesRepositoryProvider),
    beverageStore: ref.watch(beverageStoreProvider),
  ),
);

final bleDeviceRepositoryProvider = Provider<BleDeviceRepository>(
  (ref) => BleDeviceRepositoryImpl(ref.watch(sharedPreferencesProvider)),
);

final appleHealthImportRepositoryProvider =
    Provider<AppleHealthImportRepository>(
  (ref) => AppleHealthImportRepositoryImpl(ref.watch(healthDataSourceProvider)),
);

final appleHealthImportServiceProvider = Provider<AppleHealthImportService>(
  (ref) =>
      AppleHealthImportService(ref.watch(appleHealthImportRepositoryProvider)),
);

final appleHealthImportReportStoreProvider =
    Provider<AppleHealthImportReportStore>(
  (ref) => AppleHealthImportReportStore(ref.watch(sharedPreferencesProvider)),
);

final bodyEnergyRepositoryProvider = Provider<BodyEnergyRepository>(
  (ref) => BodyEnergyRepositoryImpl(
    heartRepository: ref.watch(heartRepositoryProvider),
    sleepRepository: ref.watch(sleepRepositoryProvider),
    activityRepository: ref.watch(activityRepositoryProvider),
    vitalsRepository: ref.watch(vitalsRepositoryProvider),
    healthRepository: ref.watch(healthRepositoryProvider),
    preferencesRepository: ref.watch(preferencesRepositoryProvider),
    cacheStore: ref.watch(bodyEnergyTimelineCacheStoreProvider),
  ),
);

// ── Read orchestrator + use cases ─────────────────────────────────────────

final dashboardDataLoaderProvider = Provider<DashboardDataLoader>(
  (ref) => DashboardDataLoader(
    ref.watch(healthDataSourceProvider),
    preferencesRepository: ref.watch(preferencesRepositoryProvider),
  ),
);

final loadDashboardDayUseCaseProvider = Provider<LoadDashboardDayUseCase>(
  (ref) => LoadDashboardDayUseCase(ref.watch(dashboardDataLoaderProvider)),
);

final loadHeartPeriodUseCaseProvider = Provider<LoadHeartPeriodUseCase>(
  (ref) => LoadHeartPeriodUseCase(
    ref.watch(heartRepositoryProvider),
    ref.watch(vitalsRepositoryProvider),
  ),
);

final loadSleepPeriodUseCaseProvider = Provider<LoadSleepPeriodUseCase>(
  (ref) => LoadSleepPeriodUseCase(
    ref.watch(sleepRepositoryProvider),
    ref.watch(heartRepositoryProvider),
  ),
);

// ── Reminders (hydration / mindfulness) ───────────────────────────────────

/// Shared local-notifications plugin instance. `initialize(...)` and timezone
/// setup (`tz.initializeTimeZones()`) are device bootstrap left for on-device.
final flutterLocalNotificationsProvider =
    Provider<FlutterLocalNotificationsPlugin>(
  (ref) => FlutterLocalNotificationsPlugin(),
);

final hydrationReminderDeviceProvider = Provider<HydrationReminderDevice>(
  (ref) => HydrationReminderDevice(
    ref.watch(flutterLocalNotificationsProvider),
  ),
);

final hydrationReminderControllerProvider =
    Provider<HydrationReminderController>((ref) {
  final device = ref.watch(hydrationReminderDeviceProvider);
  return HydrationReminderController(
    preferences: ref.watch(preferencesRepositoryProvider),
    hydrationRepository: ref.watch(hydrationRepositoryProvider),
    notifier: device,
    scheduler: device,
  );
});

final mindfulnessReminderDeviceProvider = Provider<MindfulnessReminderDevice>(
  (ref) => MindfulnessReminderDevice(
    ref.watch(flutterLocalNotificationsProvider),
  ),
);

final mindfulnessReminderControllerProvider =
    Provider<MindfulnessReminderController>((ref) {
  final device = ref.watch(mindfulnessReminderDeviceProvider);
  return MindfulnessReminderController(
    preferences: ref.watch(preferencesRepositoryProvider),
    mindfulnessRepository: ref.watch(mindfulnessRepositoryProvider),
    notifier: device,
    scheduler: device,
  );
});

// ── Home-screen widgets ───────────────────────────────────────────────────

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => const HomeWidgetService(),
);

// ── Offline maps ──────────────────────────────────────────────────────────

/// Import controller for offline map packs. Async because it resolves the
/// app's private maps directory; the metadata is persisted in SharedPreferences.
final offlineMapImportControllerProvider =
    FutureProvider<OfflineMapImportController>((ref) async {
  final documentsDir = await getApplicationDocumentsDirectory();
  final mapsDirectoryPath = p.join(documentsDir.path, 'offline_maps');
  final metadataStore = OfflineMapMetadataStore.sharedPreferences(
    ref.watch(sharedPreferencesProvider),
    mapsDirectoryPath,
  );
  return OfflineMapImportController(
    metadataStore: metadataStore,
    mapsDirectoryPath: mapsDirectoryPath,
  );
});
