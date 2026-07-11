import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../di/providers.dart';
import '../../domain/model/dashboard_query.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_providers.dart';
import '../../ui/theme/app_theme.dart';
import 'home_widget_snapshots.dart';

/// Configuring a placed metric widget — the Flutter half of the Kotlin
/// `HomeMetricWidgetConfigurationActivity`.
///
/// Kotlin could put the picker in a native `ListView` activity because the metric
/// catalog, its titles and its formatting all live in Kotlin. Here they live in
/// Dart, so the *Flutter activity is the configuration activity*: the metric
/// widget's `android:configure` points at `MainActivity`, and the `home_widget`
/// plugin recognises the `APPWIDGET_CONFIGURE` intent —
/// [HomeWidget.initiallyLaunchedFromHomeWidgetConfigure] hands us the appWidgetId
/// (and sets `RESULT_CANCELED` for us, so backing out drops the widget, exactly
/// as Kotlin's `setResult(RESULT_CANCELED)` in `onCreate` does).
///
/// The picked metric is persisted as the instance's `selection_id`, which is the
/// contract `HomeWidgetRefresher` reads back to know what each tile shows. Kotlin
/// additionally kept the choice in an `AppWidgetOptions` bundle and a private
/// SharedPreferences file, with a "pending metric" TTL to bridge the two — none of
/// which is needed here: the plugin's preferences file is the single source of
/// truth for both sides.

/// Thin seam over the plugin's configuration channel, so the picker is testable
/// without an Android host (the same shape as `HomeWidgetLaunchChannel`).
class HomeWidgetConfigureChannel {
  const HomeWidgetConfigureChannel();

  /// The appWidgetId the app was launched to configure, or null on a normal
  /// launch (and on every host without the plugin).
  Future<int?> pendingAppWidgetId() async {
    try {
      final id = await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure();
      // The plugin hands the id over as a String.
      return id == null ? null : int.tryParse(id);
    } on PlatformException catch (error) {
      debugPrint('initiallyLaunchedFromHomeWidgetConfigure failed: $error');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Completes the configuration with `RESULT_OK`, which is what tells Android to
  /// keep the widget. Not calling it leaves the `RESULT_CANCELED` the plugin set,
  /// so a user who backs out never gets a half-configured tile.
  Future<void> finish() async {
    try {
      await HomeWidget.finishHomeWidgetConfigure();
    } on PlatformException catch (error) {
      debugPrint('finishHomeWidgetConfigure failed: $error');
    } on MissingPluginException {
      // No host to finish against (tests, desktop).
    }
  }
}

final homeWidgetConfigureChannelProvider = Provider<HomeWidgetConfigureChannel>(
  (ref) => const HomeWidgetConfigureChannel(),
);

/// The whole app, when it was launched to configure a metric widget.
///
/// Deliberately *not* the normal [OpenVitalsApp] with a route pushed on top: a
/// configuration launch is a modal, single-purpose activity that finishes as soon
/// as the user picks (or backs out), and the router's dashboard has no business
/// booting up behind it. `main()` mounts this instead of the app.
class HomeMetricWidgetConfigureApp extends ConsumerWidget {
  const HomeMetricWidgetConfigureApp({super.key, required this.appWidgetId});

  final int appWidgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    final tag = language.languageTag;
    return MaterialApp(
      title: 'OpenVitals',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFrom(AppTheme.lightScheme),
      darkTheme: AppTheme.themeFrom(AppTheme.darkScheme),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: tag == null ? null : Locale(tag),
      home: HomeMetricWidgetConfigureScreen(appWidgetId: appWidgetId),
    );
  }
}

/// The metric picker (Kotlin's `ListView` of `homeMetricWidgetCatalog()`).
class HomeMetricWidgetConfigureScreen extends ConsumerStatefulWidget {
  const HomeMetricWidgetConfigureScreen({super.key, required this.appWidgetId});

  final int appWidgetId;

  @override
  ConsumerState<HomeMetricWidgetConfigureScreen> createState() =>
      _HomeMetricWidgetConfigureScreenState();
}

class _HomeMetricWidgetConfigureScreenState
    extends ConsumerState<HomeMetricWidgetConfigureScreen> {
  /// Set while the pick is being persisted and pushed. The load can take a
  /// moment, and a second tap would configure the instance twice.
  bool _configuring = false;

  Future<void> _select(DashboardMetric metric) async {
    if (_configuring) return;
    setState(() => _configuring = true);
    await ref
        .read(homeWidgetRefresherProvider)
        .configureMetricInstance(metric, appWidgetId: widget.appWidgetId);
    await ref.read(homeWidgetConfigureChannelProvider).finish();
    // The activity is finishing; nothing to reset if it somehow is not.
    if (mounted) setState(() => _configuring = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = homeMetricWidgetCatalog();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeMetricWidgetConfigTitle)),
      body: metrics.isEmpty
          ? Center(child: Text(l10n.homeMetricWidgetNoMetrics))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.homeMetricWidgetConfigPrompt,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (_configuring) const LinearProgressIndicator(),
                Expanded(
                  child: ListView.builder(
                    itemCount: metrics.length,
                    itemBuilder: (context, index) {
                      final metric = metrics[index];
                      return ListTile(
                        title: Text(homeWidgetMetricTitle(metric, l10n)),
                        onTap: _configuring ? null : () => _select(metric),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
