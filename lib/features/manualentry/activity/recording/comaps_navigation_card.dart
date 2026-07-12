import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/model/comaps_navigation.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../ui/components/ov_surface.dart';
import 'comaps_navigation_display.dart';

/// Port of the Kotlin `CoMapsNavigationContextCard.kt`.
///
/// CoMaps plans and navigates; OpenVitals records. Everything here READS what
/// CoMaps is already doing — and every state it can be in, including the four
/// that say "no guidance", is an ordinary one: the recording never depends on
/// any of them, so none of them shouts.

/// CoMaps' own guidance green, which the overlay borrows so a turn instruction
/// reads as CoMaps' voice rather than as one of the app's own metrics.
const Color kCoMapsGuidanceGreen = Color(0xFF4F7F50);
const Color kCoMapsGuidanceGreenDark = Color(0xFF3E6A43);

/// How far to rotate the forward arrow for each turn. Kotlin
/// `CoMapsTurnKind.rotationDegrees`: the icon points right at 0°, so straight
/// ahead is a quarter turn back.
double coMapsTurnRotationDegrees(CoMapsTurnKind kind) => switch (kind) {
      CoMapsTurnKind.straight => -90,
      CoMapsTurnKind.right => 0,
      CoMapsTurnKind.slightRight => -45,
      CoMapsTurnKind.sharpRight => 35,
      CoMapsTurnKind.left => 180,
      CoMapsTurnKind.slightLeft => -135,
      CoMapsTurnKind.sharpLeft => 145,
      CoMapsTurnKind.uTurn => 90,
      CoMapsTurnKind.roundabout => 45,
      CoMapsTurnKind.finish => 0,
      CoMapsTurnKind.unknown => -90,
    };

/// The whole live-guidance surface of the recording screen, dispatching on what
/// CoMaps can currently tell us.
///
/// [CoMapsNavigationDisabled] renders NOTHING — the user never asked for this,
/// and a panel explaining that a feature they did not switch on is off would be
/// the loudest thing on the screen.
class CoMapsGuidancePanel extends StatelessWidget {
  const CoMapsGuidancePanel({
    super.key,
    required this.state,
    required this.onRequestPermission,
  });

  final CoMapsNavigationState state;
  final VoidCallback onRequestPermission;

  @override
  Widget build(BuildContext context) {
    final navigation = state;
    if (navigation is CoMapsNavigationDisabled) return const SizedBox.shrink();
    if (navigation is CoMapsNavigationActive) {
      return CoMapsNavigationStatsPanel(snapshot: navigation.snapshot);
    }
    return _CoMapsNavigationContextCard(
      state: navigation,
      onRequestPermission: onRequestPermission,
    );
  }
}

/// Kotlin `CoMapsNavigationContextCard`: the titled card that carries the four
/// "no guidance right now" answers. Each one says, in its own words, that the
/// recording carries on — because it does.
class _CoMapsNavigationContextCard extends StatelessWidget {
  const _CoMapsNavigationContextCard({
    required this.state,
    required this.onRequestPermission,
  });

  final CoMapsNavigationState state;
  final VoidCallback onRequestPermission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // The permission is the ONE of these the user can do something about, so it
    // is the one that gets a button. The others are facts about their phone.
    final message = switch (state) {
      CoMapsNavigationPermissionMissing() =>
        l10n.activityEntryRecordingCoMapsPermissionMissing,
      CoMapsNavigationAppUnavailable() =>
        l10n.activityEntryRecordingCoMapsAppUnavailable,
      CoMapsNavigationProviderUnavailable() =>
        l10n.activityEntryRecordingCoMapsProviderUnavailable,
      CoMapsNavigationNotNavigating() =>
        l10n.activityEntryRecordingCoMapsNotNavigating,
      CoMapsNavigationError() => l10n.activityEntryRecordingCoMapsError,
      _ => '',
    };

    return OpenVitalsSurface(
      contentPadding: const EdgeInsets.all(12),
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          _CoMapsTitleRow(l10n: l10n),
          Text(
            message,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (state is CoMapsNavigationPermissionMissing)
            OutlinedButton(
              onPressed: onRequestPermission,
              child: Text(l10n.activityEntryRecordingCoMapsPermissionAction),
            ),
        ],
      ),
    );
  }
}

/// Kotlin `CoMapsNavigationStatsPanel`: the turn badge, the street it is about,
/// and the six figures CoMaps is willing to hand over.
class CoMapsNavigationStatsPanel extends StatelessWidget {
  const CoMapsNavigationStatsPanel({super.key, required this.snapshot});

  final CoMapsNavigationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final display = buildCoMapsGuidanceDisplay(snapshot, l10n);

    return OpenVitalsSurface(
      style: OpenVitalsSurfaceStyle.metric,
      contentPadding: const EdgeInsets.all(14),
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              _CoMapsTurnBadge(display: display),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.activityEntryRecordingCoMapsTitle,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      display.primaryStreet,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          _CoMapsMetricRow(
            left: (l10n.activityEntryRecordingCoMapsNextTurn, display.nextTurn),
            right: (
              l10n.activityEntryRecordingCoMapsDestination,
              display.destination,
            ),
          ),
          _CoMapsMetricRow(
            left: (
              l10n.activityEntryRecordingCoMapsCurrentStreet,
              display.currentStreet,
            ),
            right: (
              l10n.activityEntryRecordingCoMapsProgress,
              display.progress,
            ),
          ),
          _CoMapsMetricRow(
            left: (
              l10n.activityEntryRecordingCoMapsTimeToNextStop,
              display.timeToNextStop,
            ),
            right: (
              l10n.activityEntryRecordingCoMapsRouteTime,
              display.routeTime,
            ),
          ),
          _CoMapsMetric(
            label: l10n.activityEntryRecordingCoMapsState,
            value: display.sessionState,
          ),
        ],
      ),
    );
  }
}

/// Kotlin `CoMapsMapGuidanceOverlay`: the turn, big enough to read at arm's
/// length on a bike. It floats over the map tab, in CoMaps' green.
class CoMapsMapGuidanceOverlay extends StatelessWidget {
  const CoMapsMapGuidanceOverlay({super.key, required this.snapshot});

  final CoMapsNavigationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final display = buildCoMapsGuidanceDisplay(snapshot, l10n);

    return OpenVitalsSurface(
      containerColor: kCoMapsGuidanceGreen,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: kCoMapsGuidanceGreenDark,
                child: SizedBox(
                  width: 112,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CoMapsTurnArrow(kind: display.turnKind, size: 52),
                        Text(
                          display.turnDistance,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        display.primaryStreet,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (display.overlaySecondary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            display.overlaySecondary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.86),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (display.overlayFooter.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            display.overlayFooter,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotlin `CoMapsTurnBadge`: the arrow and the distance to it, in a green tile.
class _CoMapsTurnBadge extends StatelessWidget {
  const _CoMapsTurnBadge({required this.display});

  final CoMapsGuidanceDisplay display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OpenVitalsSurface(
      containerColor: kCoMapsGuidanceGreen,
      contentPadding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CoMapsTurnArrow(kind: display.turnKind, size: 32),
          Text(
            display.turnDistance,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

/// One arrow, rotated to the turn it stands for — except the last "turn" of a
/// route, which is not a turn at all but an arrival, and gets a flag.
class _CoMapsTurnArrow extends StatelessWidget {
  const _CoMapsTurnArrow({required this.kind, required this.size});

  final CoMapsTurnKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (kind == CoMapsTurnKind.finish) {
      return Icon(Icons.flag_outlined, size: size, color: Colors.white);
    }
    return Transform.rotate(
      angle: coMapsTurnRotationDegrees(kind) * math.pi / 180,
      child: Icon(Icons.arrow_forward, size: size, color: Colors.white),
    );
  }
}

class _CoMapsTitleRow extends StatelessWidget {
  const _CoMapsTitleRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.map_outlined, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.activityEntryRecordingCoMapsTitle,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Two metrics side by side, each half the row.
class _CoMapsMetricRow extends StatelessWidget {
  const _CoMapsMetricRow({required this.left, required this.right});

  final (String, String) left;
  final (String, String) right;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _CoMapsMetric(label: left.$1, value: left.$2)),
          const SizedBox(width: 12),
          Expanded(child: _CoMapsMetric(label: right.$1, value: right.$2)),
        ],
      );
}

/// Kotlin `CoMapsNavigationMetric`: the value first and the label under it, the
/// way every other figure on the recording dashboard reads.
class _CoMapsMetric extends StatelessWidget {
  const _CoMapsMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
