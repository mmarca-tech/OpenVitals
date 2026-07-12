import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/result/result.dart';
import '../../../domain/model/comaps_navigation.dart';
import '../../source/comaps/comaps_navigation_source.dart';
import '../contract/comaps_navigation_repository.dart';
import 'run_catching.dart';

/// Port of the Kotlin `CoMapsNavigationClient` + `ActivityCoMapsNavigationRepository`.
class CoMapsNavigationRepositoryImpl implements CoMapsNavigationRepository {
  CoMapsNavigationRepositoryImpl(this._source, this._prefs);

  final CoMapsNavigationSource _source;
  final SharedPreferences _prefs;

  static const String _samplesKeyPrefix = 'activity_comaps_navigation_';

  @override
  Future<Result<CoMapsNavigationState>> readLive() => runCatching(() async {
        final answer = await _source.queryLive();
        return _stateFrom(answer);
      });

  @override
  Future<Result<bool>> hasPermission() =>
      runCatching(() => _source.hasPermission());

  @override
  Future<Result<bool>> requestPermission() =>
      runCatching(() => _source.requestPermission());

  @override
  Future<Result<bool>> canLaunchCoMaps() =>
      runCatching(() => _source.canLaunch());

  @override
  Future<Result<bool>> launchForPlanning({
    double? latitude,
    double? longitude,
  }) =>
      runCatching(() => _source.launchForPlanning(
            latitude: latitude,
            longitude: longitude,
          ));

  @override
  Future<Result<void>> saveSamples(
    String activityId,
    List<CoMapsNavigationSnapshot> samples,
  ) =>
      runCatching(() async {
        final key = '$_samplesKeyPrefix$activityId';
        if (samples.isEmpty) {
          await _prefs.remove(key);
          return;
        }
        await _prefs.setString(key, encodeCoMapsSamples(samples));
      });

  @override
  Future<Result<List<CoMapsNavigationSnapshot>>> loadSamples(
    String activityId,
  ) =>
      runCatching(() async {
        final raw = _prefs.getString('$_samplesKeyPrefix$activityId');
        if (raw == null || raw.isEmpty) return const <CoMapsNavigationSnapshot>[];
        return decodeCoMapsSamples(raw);
      });

  /// Turns the platform's answer into the domain's answer.
  ///
  /// The unavailable statuses are not failures — they are what the screen shows
  /// the user, and each one says something different about what they could do
  /// about it.
  CoMapsNavigationState _stateFrom(Map<Object?, Object?> answer) {
    switch (answer['status']) {
      case 'active':
        final row = (answer['row'] as Map?) ?? const {};
        return CoMapsNavigationActive(_snapshotFrom(row));
      case 'notNavigating':
        return const CoMapsNavigationNotNavigating();
      case 'permissionMissing':
        return const CoMapsNavigationPermissionMissing();
      case 'providerUnavailable':
        return const CoMapsNavigationProviderUnavailable();
      case 'appUnavailable':
        return const CoMapsNavigationAppUnavailable();
      default:
        return CoMapsNavigationError(answer['message'] as String?);
    }
  }

  CoMapsNavigationSnapshot _snapshotFrom(Map<Object?, Object?> row) {
    String text(String column) => (row[column] as String?)?.trim() ?? '';
    int? whole(String column) => switch (row[column]) {
          final int value => value,
          // The channel widens Kotlin's Long, and a provider may answer a
          // formatted string where we expected a number.
          final num value => value.toInt(),
          final String value => int.tryParse(value),
          _ => null,
        };
    double? fraction(String column) => switch (row[column]) {
          final num value => value.toDouble(),
          final String value => double.tryParse(value),
          _ => null,
        };

    return CoMapsNavigationSnapshot(
      sampledAt: DateTime.now(),
      sessionState: text('session_state'),
      currentStreet: text('current_street'),
      nextStreet: text('next_street'),
      distanceToTurn: text('dist_to_turn'),
      distanceToTarget: text('dist_to_target'),
      distanceToNextStop: text('dist_to_next_stop'),
      totalTimeSeconds: whole('total_time_seconds'),
      timeToNextStopSeconds: whole('time_to_next_stop'),
      completionPercent: fraction('completion_percent'),
      carDirection: text('car_direction'),
      pedestrianDirection: text('pedestrian_direction'),
      exitNumber: text('exit_num'),
    );
  }
}

/// The samples as stored. A plain JSON list, versioned by nothing — if the shape
/// ever changes, a decode failure drops the history for that activity rather
/// than taking the activity down with it (see [decodeCoMapsSamples]).
String encodeCoMapsSamples(List<CoMapsNavigationSnapshot> samples) =>
    jsonEncode([
      for (final sample in samples)
        {
          'sampledAt': sample.sampledAt.toUtc().toIso8601String(),
          'sessionState': sample.sessionState,
          'currentStreet': sample.currentStreet,
          'nextStreet': sample.nextStreet,
          'distanceToTurn': sample.distanceToTurn,
          'distanceToTarget': sample.distanceToTarget,
          'distanceToNextStop': sample.distanceToNextStop,
          'totalTimeSeconds': sample.totalTimeSeconds,
          'timeToNextStopSeconds': sample.timeToNextStopSeconds,
          'completionPercent': sample.completionPercent,
          'carDirection': sample.carDirection,
          'pedestrianDirection': sample.pedestrianDirection,
          'exitNumber': sample.exitNumber,
        },
    ]);

/// Decodes what [encodeCoMapsSamples] wrote, oldest first.
///
/// Guidance context is a nicety attached to an activity; a corrupt or
/// unreadable blob must never cost the user the activity itself, so anything
/// unparseable simply yields no samples.
List<CoMapsNavigationSnapshot> decodeCoMapsSamples(String raw) {
  final List<dynamic> entries;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    entries = decoded;
  } on FormatException {
    return const [];
  }

  final samples = <CoMapsNavigationSnapshot>[];
  for (final entry in entries) {
    if (entry is! Map) continue;
    final sampledAt = DateTime.tryParse('${entry['sampledAt']}');
    if (sampledAt == null) continue;
    samples.add(CoMapsNavigationSnapshot(
      sampledAt: sampledAt.toLocal(),
      sessionState: '${entry['sessionState'] ?? ''}',
      currentStreet: '${entry['currentStreet'] ?? ''}',
      nextStreet: '${entry['nextStreet'] ?? ''}',
      distanceToTurn: '${entry['distanceToTurn'] ?? ''}',
      distanceToTarget: '${entry['distanceToTarget'] ?? ''}',
      distanceToNextStop: '${entry['distanceToNextStop'] ?? ''}',
      totalTimeSeconds: (entry['totalTimeSeconds'] as num?)?.toInt(),
      timeToNextStopSeconds: (entry['timeToNextStopSeconds'] as num?)?.toInt(),
      completionPercent: (entry['completionPercent'] as num?)?.toDouble(),
      carDirection: '${entry['carDirection'] ?? ''}',
      pedestrianDirection: '${entry['pedestrianDirection'] ?? ''}',
      exitNumber: '${entry['exitNumber'] ?? ''}',
    ));
  }
  // The Kotlin repository sorted on read; a recorder appends in order, but a
  // file written by an older build need not be in order.
  samples.sort((a, b) => a.sampledAt.compareTo(b.sampledAt));
  return samples;
}
