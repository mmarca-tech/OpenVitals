import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:openvitals/health/health_connect_mappers.dart';

HealthDataPoint _point({
  required HealthDataType type,
  required HealthDataUnit unit,
  required num value,
  required DateTime from,
  required DateTime to,
  String uuid = 'uuid-1',
  String sourceName = 'com.example.source',
}) =>
    HealthDataPoint(
      uuid: uuid,
      value: NumericHealthValue(numericValue: value),
      type: type,
      unit: unit,
      dateFrom: from,
      dateTo: to,
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'device',
      sourceId: '',
      sourceName: sourceName,
    );

void main() {
  final from = DateTime.utc(2026, 1, 2, 8);
  final to = DateTime.utc(2026, 1, 2, 8, 30);

  test('heart-rate sample maps value, time and source', () {
    final point = _point(
      type: HealthDataType.HEART_RATE,
      unit: HealthDataUnit.BEATS_PER_MINUTE,
      value: 72.4,
      from: from,
      to: from,
    );
    final sample = HealthConnectMappers.heartRateSample(point);
    expect(sample.beatsPerMinute, 72); // rounded
    expect(sample.time, from);
    expect(sample.source, 'com.example.source');
  });

  test('height converts metres to centimetres', () {
    final point = _point(
      type: HealthDataType.HEIGHT,
      unit: HealthDataUnit.METER,
      value: 1.83,
      from: from,
      to: from,
    );
    final entry = HealthConnectMappers.heightEntry(point, null);
    expect(entry.heightCm, closeTo(183.0, 1e-9));
  });

  test('ownership tag is set only when source == app package', () {
    final owned = _point(
      type: HealthDataType.WEIGHT,
      unit: HealthDataUnit.KILOGRAM,
      value: 80,
      from: from,
      to: from,
      sourceName: 'tech.mmarca.openvitals',
    );
    final foreign = _point(
      type: HealthDataType.WEIGHT,
      unit: HealthDataUnit.KILOGRAM,
      value: 80,
      from: from,
      to: from,
      sourceName: 'com.other.app',
    );
    expect(
      HealthConnectMappers.weightEntry(owned, 'tech.mmarca.openvitals')
          .isOpenVitalsEntry,
      isTrue,
    );
    expect(
      HealthConnectMappers.weightEntry(foreign, 'tech.mmarca.openvitals')
          .isOpenVitalsEntry,
      isFalse,
    );
    // With no known package name, nothing is treated as owned.
    expect(HealthConnectMappers.weightEntry(owned, null).isOpenVitalsEntry, isFalse);
  });

  test('mindfulness session derives duration from the span', () {
    final point = _point(
      type: HealthDataType.WORKOUT, // avoid the SLEEP/MINDFULNESS minute-convert
      unit: HealthDataUnit.NO_UNIT,
      value: 0,
      from: from,
      to: to,
      uuid: 'm1',
    );
    final session = HealthConnectMappers.mindfulnessSession(point, null);
    expect(session.durationMs, 30 * 60 * 1000);
    expect(session.id, 'm1');
  });

  test('daily heart-rate summaries aggregate per calendar day', () {
    final samples = [
      HealthConnectMappers.heartRateSample(
        _point(
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          value: 60,
          from: DateTime.utc(2026, 1, 2, 6),
          to: DateTime.utc(2026, 1, 2, 6),
        ),
      ),
      HealthConnectMappers.heartRateSample(
        _point(
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          value: 80,
          from: DateTime.utc(2026, 1, 2, 18),
          to: DateTime.utc(2026, 1, 2, 18),
        ),
      ),
    ];
    final summaries = HealthConnectMappers.dailyHeartRateSummaries(samples);
    expect(summaries, hasLength(1));
    expect(summaries.single.minBpm, 60);
    expect(summaries.single.maxBpm, 80);
    expect(summaries.single.avgBpm, 70);
  });
}
