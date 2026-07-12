import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openvitals/domain/model/comaps_navigation.dart';
import 'package:openvitals/features/manualentry/activity/recording/comaps_navigation_card.dart';
import 'package:openvitals/features/manualentry/activity/recording/comaps_navigation_display.dart';
import 'package:openvitals/l10n/app_localizations.dart';

/// The live CoMaps guidance surface of the recording screen.
///
/// The invariant under all of this: CoMaps guidance is a BONUS on top of a
/// recording, so no state of it may ever look like the recording is in trouble.
/// Four of the seven states say, in so many words, "recording continues"; one —
/// the missing permission — is the only one the user can act on, and the only
/// one that gets a button; and the state the user never asked for renders
/// nothing at all.
CoMapsNavigationSnapshot _snapshot({
  String sessionState = 'Following route',
  String currentStreet = 'Baker Street',
  String nextStreet = 'Elm Street',
  String distanceToTurn = '450 m',
  String distanceToTarget = '3.2 km',
  String distanceToNextStop = '',
  int? totalTimeSeconds = 1200,
  int? timeToNextStopSeconds = 260,
  double? completionPercent = 62.6,
  String carDirection = 'TURN_RIGHT',
  String pedestrianDirection = '',
  String exitNumber = '',
}) =>
    CoMapsNavigationSnapshot(
      sampledAt: DateTime.utc(2026, 7, 12, 10, 32),
      sessionState: sessionState,
      currentStreet: currentStreet,
      nextStreet: nextStreet,
      distanceToTurn: distanceToTurn,
      distanceToTarget: distanceToTarget,
      distanceToNextStop: distanceToNextStop,
      totalTimeSeconds: totalTimeSeconds,
      timeToNextStopSeconds: timeToNextStopSeconds,
      completionPercent: completionPercent,
      carDirection: carDirection,
      pedestrianDirection: pedestrianDirection,
      exitNumber: exitNumber,
    );

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('CoMapsGuidancePanel', () {
    testWidgets('Active shows the turn, the streets and the route figures',
        (tester) async {
      await _pump(
        tester,
        CoMapsGuidancePanel(
          state: CoMapsNavigationActive(_snapshot(exitNumber: '3')),
          onRequestPermission: () {},
        ),
      );

      expect(find.text('CoMaps guidance'), findsOneWidget);
      // The street being guided towards, and the turn onto it.
      expect(find.text('Elm Street'), findsOneWidget);
      expect(
        find.text('450 m - Elm Street - Turn right - Exit 3'),
        findsOneWidget,
      );
      // The distance to the turn also rides on the badge.
      expect(find.text('450 m'), findsOneWidget);
      expect(find.text('Baker Street'), findsOneWidget);
      expect(find.text('3.2 km'), findsOneWidget);
      // 62.6% is not a figure anyone reads mid-run.
      expect(find.text('63% complete'), findsOneWidget);
      expect(find.text('Following route'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('4:20'), findsOneWidget);
      // Nothing here is actionable: guidance is arriving.
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('PermissionMissing explains itself AND offers the button',
        (tester) async {
      var requested = 0;
      await _pump(
        tester,
        CoMapsGuidancePanel(
          state: const CoMapsNavigationPermissionMissing(),
          onRequestPermission: () => requested++,
        ),
      );

      expect(
        find.text('CoMaps navigation data permission is missing. Recording '
            'will continue without guidance context.'),
        findsOneWidget,
      );

      final button = find.widgetWithText(
        OutlinedButton,
        'Allow CoMaps guidance',
      );
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();
      expect(requested, 1);
    });

    testWidgets('Disabled renders nothing at all', (tester) async {
      await _pump(
        tester,
        CoMapsGuidancePanel(
          state: const CoMapsNavigationDisabled(),
          onRequestPermission: () {},
        ),
      );

      // Not the title, not a line of explanation, not a pixel: the user never
      // switched this on.
      expect(find.text('CoMaps guidance'), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('the unavailable states say the recording carries on',
        (tester) async {
      final cases = <CoMapsNavigationState, String>{
        const CoMapsNavigationAppUnavailable():
            'CoMaps is not installed. Recording will continue normally.',
        const CoMapsNavigationProviderUnavailable():
            'This CoMaps build does not expose live navigation data. '
                'Recording will continue normally.',
        const CoMapsNavigationNotNavigating():
            'CoMaps is available but not actively navigating.',
        const CoMapsNavigationError('provider blew up'):
            'CoMaps guidance is temporarily unavailable. Recording will '
                'continue normally.',
      };

      for (final entry in cases.entries) {
        await _pump(
          tester,
          CoMapsGuidancePanel(
            state: entry.key,
            onRequestPermission: () {},
          ),
        );

        expect(find.text('CoMaps guidance'), findsOneWidget);
        expect(find.text(entry.value), findsOneWidget);
        // Only the missing permission is something the user can fix.
        expect(find.byType(OutlinedButton), findsNothing);
        // The raw failure message is never shown: it is CoMaps' problem, not a
        // sentence anybody wants mid-run.
        expect(find.text('provider blew up'), findsNothing);
      }
    });
  });

  group('CoMapsMapGuidanceOverlay', () {
    testWidgets('is the turn, the street and the distance, and no more',
        (tester) async {
      await _pump(
        tester,
        CoMapsMapGuidanceOverlay(snapshot: _snapshot()),
      );

      expect(find.text('Elm Street'), findsOneWidget);
      expect(find.text('450 m'), findsOneWidget);
      // The secondary line carries the direction and the street being left.
      expect(
        find.text('Turn right - Baker Street - Destination 3.2 km'),
        findsOneWidget,
      );
      expect(
        find.text('63% complete - Next stop 4:20 - Route 20:00'),
        findsOneWidget,
      );
    });

    testWidgets('falls back to the destination when there is no turn ahead',
        (tester) async {
      await _pump(
        tester,
        CoMapsMapGuidanceOverlay(
          snapshot: _snapshot(
            nextStreet: '',
            distanceToTurn: '',
            carDirection: 'REACHED_DESTINATION',
          ),
        ),
      );

      // No next street: the current one is the headline. No distance to a turn:
      // the distance to the destination takes its place.
      expect(find.text('Baker Street'), findsOneWidget);
      expect(find.text('3.2 km'), findsOneWidget);
      // Arrival is a flag, not an arrow.
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsNothing);
    });
  });

  group('buildCoMapsGuidanceDisplay', () {
    late AppLocalizations l10n;

    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('an empty snapshot says "Unavailable" rather than nothing', () {
      final display = buildCoMapsGuidanceDisplay(
        CoMapsNavigationSnapshot(
          sampledAt: DateTime.utc(2026, 7, 12),
          sessionState: '',
        ),
        l10n,
      );

      expect(display.turnKind, CoMapsTurnKind.unknown);
      expect(display.turnDistance, '--');
      expect(display.primaryStreet, '');
      expect(display.nextTurn, 'Unavailable');
      expect(display.currentStreet, 'Current street unavailable');
      expect(display.destination, 'Destination distance unavailable');
      expect(display.progress, 'Unavailable');
      expect(display.routeTime, 'Unavailable');
      expect(display.sessionState, 'Unavailable');
      expect(display.overlaySecondary, '');
      expect(display.overlayFooter, '');
    });

    test('a walking route reads the pedestrian direction', () {
      final display = buildCoMapsGuidanceDisplay(
        _snapshot(carDirection: '', pedestrianDirection: 'TurnSlightLeft'),
        l10n,
      );

      expect(display.turnKind, CoMapsTurnKind.slightLeft);
      expect(display.nextTurn, '450 m - Elm Street - Turn slight left');
    });

    test('a negative remaining time is not a negative clock', () {
      final display = buildCoMapsGuidanceDisplay(
        _snapshot(totalTimeSeconds: -5, timeToNextStopSeconds: 0),
        l10n,
      );

      expect(display.routeTime, '0:00');
      expect(display.timeToNextStop, '0:00');
    });
  });

  group('coMapsTurnRotationDegrees', () {
    test('every turn kind has an angle, and right is the unrotated arrow', () {
      expect(coMapsTurnRotationDegrees(CoMapsTurnKind.right), 0);
      expect(coMapsTurnRotationDegrees(CoMapsTurnKind.left), 180);
      expect(coMapsTurnRotationDegrees(CoMapsTurnKind.straight), -90);
      expect(coMapsTurnRotationDegrees(CoMapsTurnKind.uTurn), 90);
      for (final kind in CoMapsTurnKind.values) {
        expect(coMapsTurnRotationDegrees(kind), isA<double>());
      }
    });
  });
}
