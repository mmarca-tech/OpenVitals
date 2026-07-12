import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:openvitals/core/result/result.dart';
import 'package:openvitals/data/repository/impl/comaps_navigation_repository_impl.dart';
import 'package:openvitals/data/source/comaps/comaps_navigation_source.dart';
import 'package:openvitals/domain/model/comaps_navigation.dart';

/// Answers the channel the way the platform does, without a platform.
CoMapsNavigationSource _source(Map<String, Object?> Function(String) answer) {
  const channel = MethodChannel('tech.mmarca.openvitals/comaps_navigation');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    channel,
    (call) async => answer(call.method),
  );
  return const CoMapsNavigationSource(channel: channel);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    prefs = await SharedPreferences.getInstance();
  });

  group('reading what CoMaps is doing', () {
    test('a live row becomes an active state', () async {
      final repository = CoMapsNavigationRepositoryImpl(
        _source((_) => {
              'status': 'active',
              'row': {
                'session_state': 'OnRoute',
                'current_street': 'Tartu mnt',
                'next_street': 'Liivalaia',
                // CoMaps formats distances itself, against its own locale and
                // units. We keep the string it gives us.
                'dist_to_turn': '450 m',
                'dist_to_target': '3.2 km',
                'total_time_seconds': 1260,
                'completion_percent': 42.5,
                'car_direction': 'TurnRight',
                'exit_num': '3',
              },
            }),
        prefs,
      );

      final state = (await repository.readLive()).orThrow();

      expect(state, isA<CoMapsNavigationActive>());
      final snapshot = (state as CoMapsNavigationActive).snapshot;
      expect(snapshot.currentStreet, 'Tartu mnt');
      expect(snapshot.distanceToTurn, '450 m');
      expect(snapshot.totalTimeSeconds, 1260);
      expect(snapshot.completionPercent, 42.5);
      expect(coMapsTurnKindForDirection(snapshot.carDirection),
          CoMapsTurnKind.right);
    });

    test('each unavailable status maps to its own state', () async {
      // These are four different things to tell a user, and only one of them is
      // worth offering a button for.
      for (final (status, matcher) in <(String, TypeMatcher)>[
        ('notNavigating', isA<CoMapsNavigationNotNavigating>()),
        ('permissionMissing', isA<CoMapsNavigationPermissionMissing>()),
        ('providerUnavailable', isA<CoMapsNavigationProviderUnavailable>()),
        ('appUnavailable', isA<CoMapsNavigationAppUnavailable>()),
      ]) {
        final repository = CoMapsNavigationRepositoryImpl(
          _source((_) => {'status': status}),
          prefs,
        );

        expect((await repository.readLive()).orThrow(), matcher,
            reason: 'status $status');
      }
    });

    test('a platform failure is a state, not a thrown error', () async {
      // A recording must not fall over because a map app did.
      final repository = CoMapsNavigationRepositoryImpl(
        _source((_) => {'status': 'error', 'message': 'provider died'}),
        prefs,
      );

      final state = (await repository.readLive()).orThrow();

      expect(state, isA<CoMapsNavigationError>());
      expect((state as CoMapsNavigationError).message, 'provider died');
    });
  });

  group('the guidance kept with an activity', () {
    final samples = [
      CoMapsNavigationSnapshot(
        sampledAt: DateTime.utc(2026, 7, 4, 10),
        sessionState: 'OnRoute',
        currentStreet: 'Liivalaia',
        distanceToTurn: '450 m',
        totalTimeSeconds: 1260,
        completionPercent: 12.5,
        carDirection: 'TurnRight',
      ),
      CoMapsNavigationSnapshot(
        sampledAt: DateTime.utc(2026, 7, 4, 10, 0, 15),
        sessionState: 'OnRoute',
        currentStreet: 'Tartu mnt',
      ),
    ];

    test('survives a round trip', () async {
      final repository = CoMapsNavigationRepositoryImpl(
        _source((_) => const {'status': 'notNavigating'}),
        prefs,
      );

      (await repository.saveSamples('activity-1', samples)).orThrow();
      final loaded = (await repository.loadSamples('activity-1')).orThrow();

      expect(loaded, hasLength(2));
      expect(loaded.first.currentStreet, 'Liivalaia');
      expect(loaded.first.distanceToTurn, '450 m');
      expect(loaded.first.totalTimeSeconds, 1260);
      expect(loaded.first.completionPercent, 12.5);
      expect(loaded.last.currentStreet, 'Tartu mnt');
    });

    test('comes back oldest first, whatever order it was written in', () async {
      final repository = CoMapsNavigationRepositoryImpl(
        _source((_) => const {'status': 'notNavigating'}),
        prefs,
      );

      (await repository.saveSamples('activity-1', samples.reversed.toList()))
          .orThrow();

      final loaded = (await repository.loadSamples('activity-1')).orThrow();
      expect(loaded.first.sampledAt.isBefore(loaded.last.sampledAt), isTrue);
    });

    test('an activity with no guidance has none', () async {
      final repository = CoMapsNavigationRepositoryImpl(
        _source((_) => const {'status': 'notNavigating'}),
        prefs,
      );

      expect((await repository.loadSamples('activity-9')).orThrow(), isEmpty);
    });

    test('unreadable history costs the history, never the activity', () async {
      // Guidance context is a nicety hung off an activity. A blob written by a
      // future build must not be able to take the activity down with it.
      SharedPreferences.setMockInitialValues(
        const {'activity_comaps_navigation_activity-1': 'not json at all'},
      );
      final repository = CoMapsNavigationRepositoryImpl(
        _source((_) => const {'status': 'notNavigating'}),
        await SharedPreferences.getInstance(),
      );

      expect((await repository.loadSamples('activity-1')).orThrow(), isEmpty);
    });
  });
}
