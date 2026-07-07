import 'package:home_widget/home_widget.dart';

/// Home-screen widgets exposed by the Kotlin app, ported to the Dart side.
///
/// The native widget layouts are Android Glance (`GlanceAppWidget`) and, on
/// iOS, WidgetKit. Those are platform code and are Phase 8 work
/// (// TODO(phase8-native-widget)); this file only ports the Dart data side:
/// map a dashboard/status summary into the flat key/value payload the native
/// widget reads, and push it via the `home_widget` plugin.
///
/// The Kotlin `AndroidManifest` registers these widget providers (enumerated by
/// [HomeWidgetId]):
///  * `HomeMetricWidgetReceiver`            — configurable single-metric tile
///  * `HomeQuickBeverageWidgetReceiver`     — configurable quick-add beverage
///  * `HomeQuickBeverageOneTapWidgetReceiver` — one-tap quick-add beverage
///  * `HomeDailyReadinessWidgetReceiver`    — daily readiness score
///  * `HomeBodyEnergyWidgetReceiver`        — body energy score
///  * `HomeTodayVitalsWidgetReceiver`       — multi-row "today" summary
enum HomeWidgetId {
  metric('features.homewidgets.HomeMetricWidgetReceiver'),
  quickBeverage('features.homewidgets.HomeQuickBeverageWidgetReceiver'),
  quickBeverageOneTap('features.homewidgets.HomeQuickBeverageOneTapWidgetReceiver'),
  dailyReadiness('features.homewidgets.HomeDailyReadinessWidgetReceiver'),
  bodyEnergy('features.homewidgets.HomeBodyEnergyWidgetReceiver'),
  todayVitals('features.homewidgets.HomeTodayVitalsWidgetReceiver');

  const HomeWidgetId(this.androidReceiver);

  /// Package-relative class name of the Android widget receiver (matches the
  /// `AndroidManifest` `android:name`), package-qualified at push time.
  final String androidReceiver;
}

/// One label/value(/subtitle) row inside a widget snapshot. Mirrors the Kotlin
/// `HomeMetricWidgetRow`.
class HomeWidgetRow {
  const HomeWidgetRow({
    required this.label,
    required this.value,
    this.subtitle = '',
  });

  final String label;
  final String value;
  final String subtitle;
}

/// The flat data a home widget renders, mirroring the Kotlin
/// `HomeMetricWidgetSnapshot` (shared by every widget type).
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.title,
    this.value = '',
    this.unit = '',
    this.subtitle = '',
    this.route = defaultRoute,
    this.rows = const <HomeWidgetRow>[],
  });

  final String title;
  final String value;
  final String unit;
  final String subtitle;
  final String route;
  final List<HomeWidgetRow> rows;

  /// Fallback navigation target (the dashboard), matching `Screen.Dashboard`.
  static const String defaultRoute = 'dashboard';
}

/// Maximum rows persisted per widget, matching the Kotlin `MaxHomeWidgetRows`.
const int maxHomeWidgetRows = 12;

/// Pure mapper: [snapshot] → the flat `key → value` payload written to widget
/// storage. Keys and row layout match the Kotlin `writeHomeWidgetSnapshot` /
/// `HomeMetricWidgetState` exactly, so the native widget code can read them
/// unchanged. Rows beyond [maxHomeWidgetRows] are dropped. This is the piece
/// under unit test.
Map<String, Object> homeWidgetDataMap(
  HomeWidgetSnapshot snapshot, {
  String? metricId,
}) {
  final rowCount =
      snapshot.rows.length > maxHomeWidgetRows ? maxHomeWidgetRows : snapshot.rows.length;
  final data = <String, Object>{
    'metric_id': ?metricId,
    'title': snapshot.title,
    'value': snapshot.value,
    'unit': snapshot.unit,
    'subtitle': snapshot.subtitle,
    'route': snapshot.route,
    'row_count': rowCount,
  };
  for (var index = 0; index < rowCount; index++) {
    final row = snapshot.rows[index];
    data['row_${index}_label'] = row.label;
    data['row_${index}_value'] = row.value;
    data['row_${index}_subtitle'] = row.subtitle;
  }
  return data;
}

/// Thin seam over the `home_widget` plugin so [HomeWidgetService] is testable.
abstract interface class HomeWidgetClient {
  Future<void> saveWidgetData(String key, Object? value);

  Future<void> updateWidget({String? qualifiedAndroidName, String? iOSName});
}

/// Default [HomeWidgetClient] backed by the real `home_widget` plugin.
class PluginHomeWidgetClient implements HomeWidgetClient {
  const PluginHomeWidgetClient();

  @override
  Future<void> saveWidgetData(String key, Object? value) =>
      HomeWidget.saveWidgetData<Object?>(key, value);

  @override
  Future<void> updateWidget({String? qualifiedAndroidName, String? iOSName}) =>
      HomeWidget.updateWidget(
        qualifiedAndroidName: qualifiedAndroidName,
        iOSName: iOSName,
      );
}

/// Pushes dashboard/status summaries to the home-screen widgets.
///
/// Ported from the Kotlin `refresh*Widget` helpers: build a snapshot, flatten it
/// to key/values, persist each, then ask the OS to redraw. The native rendering
/// itself is Phase 8 platform work.
class HomeWidgetService {
  const HomeWidgetService({
    this.client = const PluginHomeWidgetClient(),
    this.androidPackageName = 'tech.mmarca.openvitals',
  });

  final HomeWidgetClient client;
  final String androidPackageName;

  /// Writes [snapshot] for [widget] and triggers a redraw. [metricId] is set for
  /// the configurable metric widget (the persisted metric selection).
  Future<void> pushSnapshot(
    HomeWidgetId widget,
    HomeWidgetSnapshot snapshot, {
    String? metricId,
  }) async {
    final data = homeWidgetDataMap(snapshot, metricId: metricId);
    for (final entry in data.entries) {
      await client.saveWidgetData(entry.key, entry.value);
    }
    await client.updateWidget(
      qualifiedAndroidName: '$androidPackageName.${widget.androidReceiver}',
    );
  }
}
