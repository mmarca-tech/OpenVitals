import 'package:freezed_annotation/freezed_annotation.dart';

part 'comaps_navigation.freezed.dart';

/// One reading of CoMaps' live navigation row.
///
/// Every field is exactly what the provider hands over — the distances arrive
/// **already formatted for display** ("450 m", "1.2 km"), because CoMaps
/// formats them against its own locale and unit settings before exposing them.
/// We do not parse them back into numbers: the number we would recover is not
/// one we could re-format any better, and a distance the user reads in CoMaps
/// should read the same here.
///
/// Port of the Kotlin `CoMapsNavigationSnapshot`.
@freezed
abstract class CoMapsNavigationSnapshot with _$CoMapsNavigationSnapshot {
  const CoMapsNavigationSnapshot._();

  const factory CoMapsNavigationSnapshot({
    required DateTime sampledAt,
    required String sessionState,
    @Default('') String currentStreet,
    @Default('') String nextStreet,
    @Default('') String distanceToTurn,
    @Default('') String distanceToTarget,
    @Default('') String distanceToNextStop,
    int? totalTimeSeconds,
    int? timeToNextStopSeconds,
    double? completionPercent,
    @Default('') String carDirection,
    @Default('') String pedestrianDirection,
    @Default('') String exitNumber,
  }) = _CoMapsNavigationSnapshot;

  /// Everything except the timestamp, so two readings taken seconds apart that
  /// say the same thing compare equal. This is what decides whether a sample is
  /// worth keeping — see [CoMapsNavigationSampleRecorder].
  String get contentKey => [
        sessionState,
        currentStreet,
        nextStreet,
        distanceToTurn,
        distanceToTarget,
        distanceToNextStop,
        totalTimeSeconds?.toString() ?? '',
        timeToNextStopSeconds?.toString() ?? '',
        completionPercent?.toString() ?? '',
        carDirection,
        pedestrianDirection,
        exitNumber,
      ].join('|');
}

/// What OpenVitals can currently learn from CoMaps.
///
/// Every one of these is a *normal* state, not an error to shout about: the
/// user is recording an activity, and CoMaps guidance is a bonus. Recording
/// continues through all of them.
sealed class CoMapsNavigationState {
  const CoMapsNavigationState();
}

/// The user has not switched the integration on.
class CoMapsNavigationDisabled extends CoMapsNavigationState {
  const CoMapsNavigationDisabled();
}

/// No known CoMaps package is installed.
class CoMapsNavigationAppUnavailable extends CoMapsNavigationState {
  const CoMapsNavigationAppUnavailable();
}

/// CoMaps is installed, but this build does not expose the navigation
/// provider (it predates the provider, or is a variant without it).
class CoMapsNavigationProviderUnavailable extends CoMapsNavigationState {
  const CoMapsNavigationProviderUnavailable();
}

/// The provider is there, but we have not been granted
/// `app.comaps.permission.READ_NAVIGATION_DATA`.
class CoMapsNavigationPermissionMissing extends CoMapsNavigationState {
  const CoMapsNavigationPermissionMissing();
}

/// CoMaps is there and readable, but is not currently guiding anyone anywhere.
/// The provider answers with an empty row.
class CoMapsNavigationNotNavigating extends CoMapsNavigationState {
  const CoMapsNavigationNotNavigating();
}

/// CoMaps is navigating, and this is what it says.
class CoMapsNavigationActive extends CoMapsNavigationState {
  const CoMapsNavigationActive(this.snapshot);

  final CoMapsNavigationSnapshot snapshot;
}

/// The query itself failed.
class CoMapsNavigationError extends CoMapsNavigationState {
  const CoMapsNavigationError([this.message]);

  final String? message;
}

/// The turn arrow to draw. CoMaps' own direction vocabulary is far richer than
/// this (it distinguishes, for instance, which side of a roundabout you leave
/// by), but a turn shown to someone mid-run has to be readable at a glance.
enum CoMapsTurnKind {
  unknown,
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
  roundabout,
  finish,
}

/// Maps a raw CoMaps direction name to a turn arrow.
///
/// CoMaps sends the *enum name* of its own direction type, and it has changed
/// spelling before — `TurnRight` in one build, `TURN_RIGHT` in another. So this
/// normalizes away case and separators and then matches on substrings, which
/// survives both. The order matters: `SHARPRIGHT` and `SLIGHTRIGHT` must be
/// tested before the bare `RIGHT` they both contain.
CoMapsTurnKind coMapsTurnKindForDirection(String direction) {
  final normalized =
      direction.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  if (normalized.isEmpty) return CoMapsTurnKind.unknown;
  if (normalized.contains('DESTINATION') ||
      normalized.contains('FINISH') ||
      normalized.contains('ARRIVE')) {
    return CoMapsTurnKind.finish;
  }
  if (normalized.contains('UTURN') || normalized.contains('TURNBACK')) {
    return CoMapsTurnKind.uTurn;
  }
  if (normalized.contains('ROUNDABOUT')) return CoMapsTurnKind.roundabout;
  if (normalized.contains('SHARPRIGHT')) return CoMapsTurnKind.sharpRight;
  if (normalized.contains('SLIGHTRIGHT')) return CoMapsTurnKind.slightRight;
  if (normalized.contains('RIGHT')) return CoMapsTurnKind.right;
  if (normalized.contains('SHARPLEFT')) return CoMapsTurnKind.sharpLeft;
  if (normalized.contains('SLIGHTLEFT')) return CoMapsTurnKind.slightLeft;
  if (normalized.contains('LEFT')) return CoMapsTurnKind.left;
  if (normalized.contains('STRAIGHT') ||
      normalized.contains('NOTURN') ||
      normalized.contains('NONE')) {
    return CoMapsTurnKind.straight;
  }
  return CoMapsTurnKind.unknown;
}

/// A raw direction name rendered as something a person would read: `TURN_RIGHT`
/// and `TurnSlightLeft` both become "Turn right" / "Turn slight left".
///
/// Deliberately not localized. It is CoMaps' vocabulary, not ours, and it is a
/// fallback for a direction we do not have an arrow for — inventing
/// translations for an enum we do not own would be worse than showing it.
String coMapsReadableDirection(String direction) {
  final words = direction
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'(?<=[a-z])(?=[A-Z])'),
        (_) => ' ',
      )
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  final first = words.first;
  return [
    first[0].toUpperCase() + first.substring(1),
    ...words.skip(1),
  ].join(' ');
}

/// Decides which live readings are worth keeping in the activity's history.
///
/// The provider will happily answer every second, and almost every answer is
/// the same as the last one. A sample is kept when the guidance actually
/// *changed*, or when [minSampleInterval] has passed since the last one kept —
/// so a long straight road costs one sample every 15 seconds rather than
/// fifteen, and a flurry of turns is never missed.
///
/// Port of the Kotlin `CoMapsNavigationSampleRecorder`.
class CoMapsNavigationSampleRecorder {
  CoMapsNavigationSampleRecorder({
    this.minSampleInterval = const Duration(seconds: 15),
  });

  final Duration minSampleInterval;
  final List<CoMapsNavigationSnapshot> _samples = [];

  void reset() => _samples.clear();

  /// Returns whether the snapshot was kept.
  bool accept(CoMapsNavigationSnapshot snapshot) {
    final previous = _samples.isEmpty ? null : _samples.last;
    final keep = previous == null ||
        previous.contentKey != snapshot.contentKey ||
        snapshot.sampledAt.difference(previous.sampledAt) >= minSampleInterval;
    if (keep) _samples.add(snapshot);
    return keep;
  }

  List<CoMapsNavigationSnapshot> get samples =>
      List<CoMapsNavigationSnapshot>.unmodifiable(_samples);
}
