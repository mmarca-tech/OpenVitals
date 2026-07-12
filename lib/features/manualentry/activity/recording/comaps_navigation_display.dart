import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/presentation/elapsed_format.dart';
import '../../../../domain/model/comaps_navigation.dart';
import '../../../../l10n/app_localizations.dart';

part 'comaps_navigation_display.freezed.dart';

/// One live CoMaps reading, turned into the strings the guidance panel and the
/// map overlay print — every fallback chosen, every list joined, every duration
/// formatted, here rather than in a build path.
///
/// A snapshot is mostly holes: CoMaps sends what it has, and what it has depends
/// on the route, the mode and the moment. Deciding *which* hole a field falls
/// back into ("next street, or the current one, or just the session state") is
/// the whole job.
@freezed
abstract class CoMapsGuidanceDisplay with _$CoMapsGuidanceDisplay {
  const factory CoMapsGuidanceDisplay({
    /// The arrow to draw.
    required CoMapsTurnKind turnKind,

    /// The distance printed under the arrow, on the badge and on the overlay.
    required String turnDistance,

    /// The street the guidance is about — the headline of the overlay.
    required String primaryStreet,

    /// "450 m - Elm Street - Turn right - Exit 3", as much of it as exists.
    required String nextTurn,
    required String currentStreet,
    required String destination,
    required String progress,
    required String timeToNextStop,
    required String routeTime,
    required String sessionState,

    /// The overlay's two secondary lines, already joined.
    required String overlaySecondary,
    required String overlayFooter,
  }) = _CoMapsGuidanceDisplay;
}

/// CoMaps drives cars and it walks people, and it fills exactly one of the two
/// direction fields depending on which. Kotlin `navigationDirection()`.
String coMapsNavigationDirection(CoMapsNavigationSnapshot snapshot) =>
    snapshot.carDirection.isNotEmpty
        ? snapshot.carDirection
        : snapshot.pedestrianDirection;

/// Pure derivation from one live reading to the strings that render it.
CoMapsGuidanceDisplay buildCoMapsGuidanceDisplay(
  CoMapsNavigationSnapshot snapshot,
  AppLocalizations l10n,
) {
  final direction = coMapsNavigationDirection(snapshot);
  final readableDirection = coMapsReadableDirection(direction);
  final unavailable = l10n.activityEntryRecordingCoMapsUnavailableShort;
  final exit = snapshot.exitNumber.isEmpty
      ? ''
      : l10n.activityEntryRecordingCoMapsExit(snapshot.exitNumber);

  // The percentage is CoMaps' own progress along its own route, and it arrives
  // as a fraction of a percent. Nobody reads decimals of a percent mid-run.
  final percent = snapshot.completionPercent;
  final completion = percent == null
      ? ''
      : l10n.activityEntryRecordingCoMapsCompletion(
          percent.round().toString(),
        );

  final nextStopTime = _formatSeconds(snapshot.timeToNextStopSeconds);
  final totalTime = _formatSeconds(snapshot.totalTimeSeconds);

  // The one distance the overlay shows, in the order the runner cares about it:
  // the turn ahead first, then the destination, then whatever stop is next.
  final overlayDistance = _firstNonEmpty([
    snapshot.distanceToTurn,
    snapshot.distanceToTarget,
    snapshot.distanceToNextStop,
  ]);
  final primaryStreet = _firstNonEmpty([
    snapshot.nextStreet,
    snapshot.currentStreet,
    snapshot.sessionState,
  ]);

  return CoMapsGuidanceDisplay(
    turnKind: coMapsTurnKindForDirection(direction),
    turnDistance: overlayDistance.isEmpty ? '--' : overlayDistance,
    primaryStreet: primaryStreet,
    nextTurn: _join([
      snapshot.distanceToTurn,
      snapshot.nextStreet,
      readableDirection,
      exit,
    ], orElse: unavailable),
    currentStreet: snapshot.currentStreet.isEmpty
        ? l10n.activityEntryRecordingCoMapsCurrentStreetUnknown
        : snapshot.currentStreet,
    destination: _firstNonEmpty([
      snapshot.distanceToTarget,
      snapshot.distanceToNextStop,
    ]).ifEmpty(l10n.activityEntryRecordingCoMapsDestinationUnknown),
    progress: completion.isEmpty ? unavailable : completion,
    timeToNextStop: nextStopTime.isEmpty ? unavailable : nextStopTime,
    routeTime: totalTime.isEmpty ? unavailable : totalTime,
    sessionState: snapshot.sessionState.isEmpty
        ? unavailable
        : snapshot.sessionState,
    overlaySecondary: _join([
      readableDirection,
      // The current street is only worth a second line when it is not already
      // the headline.
      if (snapshot.currentStreet != primaryStreet) snapshot.currentStreet,
      if (snapshot.distanceToTarget.isNotEmpty &&
          snapshot.distanceToTarget != overlayDistance)
        l10n.activityEntryRecordingCoMapsDestinationWithDistance(
          snapshot.distanceToTarget,
        ),
    ]),
    overlayFooter: _join([
      completion,
      if (nextStopTime.isNotEmpty)
        l10n.activityEntryRecordingCoMapsNextStopWithTime(nextStopTime),
      if (totalTime.isNotEmpty)
        l10n.activityEntryRecordingCoMapsRouteTimeWithDuration(totalTime),
    ]),
  );
}

/// CoMaps counts a route's remaining time in seconds; the recording screen reads
/// every other duration as `m:ss`, so this one does too.
String _formatSeconds(int? seconds) => seconds == null
    ? ''
    : formatRecordingElapsed(Duration(seconds: seconds < 0 ? 0 : seconds));

String _firstNonEmpty(List<String> candidates) => candidates.firstWhere(
      (candidate) => candidate.isNotEmpty,
      orElse: () => '',
    );

String _join(List<String> parts, {String orElse = ''}) {
  final present = [
    for (final part in parts)
      if (part.isNotEmpty) part,
  ];
  return present.isEmpty ? orElse : present.join(' - ');
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
