import 'package:openvitals/features/homewidgets/home_widget_service.dart';

/// In-memory [HomeWidgetClient]: records what a push wrote and which receivers
/// were told to redraw, and serves the widget instances the test placed.
class FakeHomeWidgetClient implements HomeWidgetClient {
  FakeHomeWidgetClient({
    this.installed = const [],
    Map<String, String>? stored,
  }) : saved = {...?stored};

  /// Everything written, and everything pre-seeded (a configured instance's
  /// `selection_id`, which the native configuration activity persists).
  final Map<String, Object?> saved;

  /// The qualified receiver of each `updateWidget` call, in order.
  final List<String?> updated = [];

  final List<HomeWidgetInstance> installed;

  @override
  Future<void> saveWidgetData(String key, Object? value) async =>
      saved[key] = value;

  @override
  Future<String?> readWidgetData(String key) async => saved[key] as String?;

  @override
  Future<void> updateWidget({
    String? qualifiedAndroidName,
    String? iOSName,
  }) async =>
      updated.add(qualifiedAndroidName);

  @override
  Future<List<HomeWidgetInstance>> installedWidgets() async => installed;
}
