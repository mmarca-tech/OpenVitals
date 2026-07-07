import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/features/homewidgets/home_widget_service.dart';

class _FakeClient implements HomeWidgetClient {
  final Map<String, Object?> saved = {};
  final List<String?> updated = [];

  @override
  Future<void> saveWidgetData(String key, Object? value) async =>
      saved[key] = value;

  @override
  Future<void> updateWidget({String? qualifiedAndroidName, String? iOSName}) async =>
      updated.add(qualifiedAndroidName);
}

void main() {
  group('homeWidgetDataMap', () {
    test('maps the snapshot to the Kotlin key layout', () {
      final data = homeWidgetDataMap(
        const HomeWidgetSnapshot(
          title: 'Readiness',
          value: '82',
          unit: '',
          subtitle: 'Prime',
          route: 'daily_readiness',
          rows: [HomeWidgetRow(label: 'Recommended', value: 'Go hard')],
        ),
        metricId: 'DAILY_READINESS',
      );

      expect(data['metric_id'], 'DAILY_READINESS');
      expect(data['title'], 'Readiness');
      expect(data['value'], '82');
      expect(data['subtitle'], 'Prime');
      expect(data['route'], 'daily_readiness');
      expect(data['row_count'], 1);
      expect(data['row_0_label'], 'Recommended');
      expect(data['row_0_value'], 'Go hard');
      expect(data['row_0_subtitle'], '');
    });

    test('omits metric_id when not provided', () {
      final data = homeWidgetDataMap(const HomeWidgetSnapshot(title: 'Today'));
      expect(data.containsKey('metric_id'), isFalse);
      expect(data['row_count'], 0);
    });

    test('caps rows at maxHomeWidgetRows', () {
      final rows = List.generate(
        maxHomeWidgetRows + 5,
        (i) => HomeWidgetRow(label: 'L$i', value: 'V$i'),
      );

      final data = homeWidgetDataMap(
        HomeWidgetSnapshot(title: 'Vitals', rows: rows),
      );

      expect(data['row_count'], maxHomeWidgetRows);
      expect(data.containsKey('row_${maxHomeWidgetRows - 1}_label'), isTrue);
      expect(data.containsKey('row_${maxHomeWidgetRows}_label'), isFalse);
    });
  });

  group('HomeWidgetService', () {
    test('persists every key then updates the qualified receiver', () async {
      final client = _FakeClient();
      final service = HomeWidgetService(client: client);

      await service.pushSnapshot(
        HomeWidgetId.bodyEnergy,
        const HomeWidgetSnapshot(title: 'Body energy', value: '64'),
      );

      expect(client.saved['title'], 'Body energy');
      expect(client.saved['value'], '64');
      expect(
        client.updated.single,
        'tech.mmarca.openvitals.features.homewidgets.HomeBodyEnergyWidgetReceiver',
      );
    });
  });
}
