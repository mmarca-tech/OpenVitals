import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:intl/intl.dart';

import '../../../domain/model/comaps_navigation.dart';
import '../../../l10n/app_localizations.dart';

part 'activity_navigation_display.freezed.dart';

final DateFormat _sampleTimeFormat = DateFormat('HH:mm');

/// One saved CoMaps reading, as the three lines the detail screen prints.
///
/// The guidance was recorded while the activity was: streets, turns, distances
/// and progress, kept in OpenVitals' own history and never written to Health
/// Connect.
@freezed
abstract class ActivityNavigationRow with _$ActivityNavigationRow {
  const factory ActivityNavigationRow({
    /// The street the guidance was about.
    required String title,

    /// "450 m to turn - 1.2 km to destination - Turn right - Exit 3".
    required String detail,

    /// "10:32 - Following route - 63% complete".
    required String meta,
  }) = _ActivityNavigationRow;
}

/// Pure derivation from the samples saved against an activity to the rows that
/// render them, oldest first — the order they were driven in.
List<ActivityNavigationRow> buildActivityNavigationRows(
  List<CoMapsNavigationSnapshot> samples,
  AppLocalizations l10n,
) {
  final ordered = [...samples]
    ..sort((a, b) => a.sampledAt.compareTo(b.sampledAt));
  return [
    for (final sample in ordered)
      ActivityNavigationRow(
        title: _firstNonEmpty([
          sample.nextStreet,
          sample.currentStreet,
          sample.sessionState,
        ]),
        detail: _join([
          if (sample.distanceToTurn.isNotEmpty)
            l10n.activityDetailNavigationToTurn(sample.distanceToTurn),
          if (sample.distanceToTarget.isNotEmpty)
            l10n.activityDetailNavigationToDestination(sample.distanceToTarget),
          if (sample.distanceToNextStop.isNotEmpty)
            l10n.activityDetailNavigationToNextStop(sample.distanceToNextStop),
          coMapsReadableDirection(
            sample.carDirection.isNotEmpty
                ? sample.carDirection
                : sample.pedestrianDirection,
          ),
          if (sample.exitNumber.isNotEmpty)
            l10n.activityEntryRecordingCoMapsExit(sample.exitNumber),
        ], orElse: sample.currentStreet),
        meta: _join([
          _sampleTimeFormat.format(sample.sampledAt.toLocal()),
          sample.sessionState,
          if (sample.completionPercent != null)
            l10n.activityEntryRecordingCoMapsCompletion(
              sample.completionPercent!.round().toString(),
            ),
        ]),
      ),
  ];
}

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
