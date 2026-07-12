import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/domain/model/comaps_navigation.dart';

CoMapsNavigationSnapshot _snapshot({
  required DateTime at,
  String currentStreet = 'Tartu mnt',
  String sessionState = 'OnRoute',
}) =>
    CoMapsNavigationSnapshot(
      sampledAt: at,
      sessionState: sessionState,
      currentStreet: currentStreet,
    );

void main() {
  group('turn kinds', () {
    // CoMaps sends the *enum name* of its own direction type, and it has spelled
    // these differently across builds — TurnRight in one, TURN_RIGHT in another.
    // These are the cases the Kotlin branch pinned, and they must still hold.
    test('reads both spellings CoMaps has used', () {
      expect(coMapsTurnKindForDirection('TURN_RIGHT'), CoMapsTurnKind.right);
      expect(coMapsTurnKindForDirection('TurnLeft'), CoMapsTurnKind.left);
      expect(
        coMapsTurnKindForDirection('TURN_SLIGHT_RIGHT'),
        CoMapsTurnKind.slightRight,
      );
      expect(
        coMapsTurnKindForDirection('TurnSharpLeft'),
        CoMapsTurnKind.sharpLeft,
      );
      expect(coMapsTurnKindForDirection('U_TURN_LEFT'), CoMapsTurnKind.uTurn);
      expect(
        coMapsTurnKindForDirection('EnterRoundabout'),
        CoMapsTurnKind.roundabout,
      );
      expect(
        coMapsTurnKindForDirection('ReachedDestination'),
        CoMapsTurnKind.finish,
      );
      expect(coMapsTurnKindForDirection('GO_STRAIGHT'), CoMapsTurnKind.straight);
    });

    test('a qualified turn beats the bare one it contains', () {
      // "TurnSlightRight" contains "RIGHT". If the bare match ran first, every
      // slight and sharp turn would draw the wrong arrow.
      expect(
        coMapsTurnKindForDirection('TurnSlightRight'),
        CoMapsTurnKind.slightRight,
      );
      expect(
        coMapsTurnKindForDirection('TurnSharpRight'),
        CoMapsTurnKind.sharpRight,
      );
      expect(coMapsTurnKindForDirection('ExitHighwayToRight'),
          CoMapsTurnKind.right);
    });

    test('an empty or unknown direction is unknown, not straight', () {
      expect(coMapsTurnKindForDirection(''), CoMapsTurnKind.unknown);
      expect(coMapsTurnKindForDirection('  '), CoMapsTurnKind.unknown);
      expect(
        coMapsTurnKindForDirection('SomethingCoMapsAddedLater'),
        CoMapsTurnKind.unknown,
      );
    });

    test('renders a raw direction as something a person would read', () {
      expect(coMapsReadableDirection('TURN_RIGHT'), 'Turn right');
      expect(coMapsReadableDirection('TurnSlightLeft'), 'Turn slight left');
      expect(coMapsReadableDirection(''), '');
    });
  });

  group('the sample recorder', () {
    final start = DateTime.utc(2026, 7, 4, 10);

    test('keeps the first reading it is given', () {
      final recorder = CoMapsNavigationSampleRecorder();

      expect(recorder.accept(_snapshot(at: start)), isTrue);
      expect(recorder.samples, hasLength(1));
    });

    test('drops a reading that says the same thing, too soon', () {
      final recorder = CoMapsNavigationSampleRecorder();
      recorder.accept(_snapshot(at: start));

      final kept = recorder.accept(
        _snapshot(at: start.add(const Duration(seconds: 5))),
      );

      expect(kept, isFalse);
      expect(recorder.samples, hasLength(1));
    });

    test('keeps a reading that says something new, however soon', () {
      // A flurry of turns must never be missed to save space.
      final recorder = CoMapsNavigationSampleRecorder();
      recorder.accept(_snapshot(at: start));

      final kept = recorder.accept(_snapshot(
        at: start.add(const Duration(seconds: 1)),
        currentStreet: 'Liivalaia',
      ));

      expect(kept, isTrue);
      expect(recorder.samples, hasLength(2));
    });

    test('keeps an unchanged reading once the interval has passed', () {
      // A long straight road costs one sample every 15 seconds, not fifteen.
      final recorder = CoMapsNavigationSampleRecorder();
      recorder.accept(_snapshot(at: start));

      expect(
        recorder.accept(_snapshot(at: start.add(const Duration(seconds: 14)))),
        isFalse,
      );
      expect(
        recorder.accept(_snapshot(at: start.add(const Duration(seconds: 15)))),
        isTrue,
      );
      expect(recorder.samples, hasLength(2));
    });

    test('reset forgets the run', () {
      final recorder = CoMapsNavigationSampleRecorder();
      recorder.accept(_snapshot(at: start));

      recorder.reset();

      expect(recorder.samples, isEmpty);
      // ...and the next reading is a first reading again.
      expect(recorder.accept(_snapshot(at: start)), isTrue);
    });
  });

  test('the content key ignores the clock and nothing else', () {
    final a = _snapshot(at: DateTime.utc(2026, 7, 4, 10));
    final b = _snapshot(at: DateTime.utc(2026, 7, 4, 11));
    final c = _snapshot(at: DateTime.utc(2026, 7, 4, 10), sessionState: 'Finish');

    expect(a.contentKey, b.contentKey);
    expect(a.contentKey, isNot(c.contentKey));
  });
}
