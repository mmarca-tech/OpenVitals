import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:openvitals/domain/model/comaps_navigation.dart';
import 'package:openvitals/features/activity/application/activity_navigation_display.dart';
import 'package:openvitals/features/activity/presentation/activity_navigation_card.dart';
import 'package:openvitals/l10n/app_localizations.dart';

/// The Navigation section of the activity detail screen: the CoMaps guidance
/// that was saved while the activity was recorded.
///
/// App-local history — none of this was ever written to Health Connect, and the
/// section exists so a rider can see afterwards what they were being told at the
/// time.
CoMapsNavigationSnapshot _sample({
  required int minute,
  String nextStreet = 'Elm Street',
  String currentStreet = 'Baker Street',
  String distanceToTurn = '450 m',
  String distanceToTarget = '',
  String exitNumber = '',
  double? completionPercent = 40,
}) =>
    CoMapsNavigationSnapshot(
      // Local, not UTC: the rows print the time the rider saw on their phone,
      // and this test must not care which zone the machine running it is in.
      sampledAt: DateTime(2026, 7, 12, 10, minute),
      sessionState: 'Following route',
      currentStreet: currentStreet,
      nextStreet: nextStreet,
      distanceToTurn: distanceToTurn,
      distanceToTarget: distanceToTarget,
      completionPercent: completionPercent,
      carDirection: 'TURN_RIGHT',
      exitNumber: exitNumber,
    );

Future<void> _pump(WidgetTester tester, List<ActivityNavigationRow> rows) =>
    tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: ActivityNavigationCard(rows: rows)),
        ),
      ),
    );

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('ActivityNavigationCard', () {
    testWidgets('lists the saved guidance, one row per sample', (tester) async {
      final rows = buildActivityNavigationRows(
        [
          _sample(minute: 32, exitNumber: '3'),
          _sample(
            minute: 47,
            nextStreet: 'Oak Avenue',
            distanceToTarget: '1.2 km',
            completionPercent: 78.4,
          ),
        ],
        l10n,
      );

      await _pump(tester, rows);

      expect(find.text('Navigation'), findsOneWidget);
      expect(find.text('No saved navigation context'), findsNothing);
      expect(find.text('Elm Street'), findsOneWidget);
      expect(find.text('Oak Avenue'), findsOneWidget);
      expect(find.text('450 m to turn - Turn right - Exit 3'), findsOneWidget);
      expect(
        find.text('450 m to turn - 1.2 km to destination - Turn right'),
        findsOneWidget,
      );
      expect(find.textContaining('Following route - 40% complete'),
          findsOneWidget);
      expect(find.textContaining('Following route - 78% complete'),
          findsOneWidget);
      // One divider between two rows, none above the first.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('says so when nothing was saved', (tester) async {
      await _pump(tester, const []);

      expect(find.text('Navigation'), findsOneWidget);
      expect(find.text('No saved navigation context'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });
  });

  group('buildActivityNavigationRows', () {
    test('orders the samples the way they were driven', () {
      final rows = buildActivityNavigationRows(
        [
          _sample(minute: 47, nextStreet: 'Oak Avenue'),
          _sample(minute: 32, nextStreet: 'Elm Street'),
        ],
        l10n,
      );

      expect(rows.map((row) => row.title), ['Elm Street', 'Oak Avenue']);
      expect(rows.first.meta.startsWith('10:32'), isTrue);
    });

    test('a sample with nothing but a street still has a detail line', () {
      final rows = buildActivityNavigationRows(
        [
          _sample(
            minute: 5,
            nextStreet: '',
            distanceToTurn: '',
            completionPercent: null,
          ),
        ],
        l10n,
      );

      expect(rows.single.title, 'Baker Street');
      expect(rows.single.detail, 'Turn right');
      expect(rows.single.meta, contains('Following route'));
    });

    test('no samples, no rows', () {
      expect(buildActivityNavigationRows(const [], l10n), isEmpty);
    });
  });
}
