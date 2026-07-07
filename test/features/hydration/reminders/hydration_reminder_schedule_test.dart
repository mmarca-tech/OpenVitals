import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/domain/model/hydration_reminder_config.dart';
import 'package:openvitals/features/hydration/reminders/hydration_reminder_schedule.dart';

/// Ported from the Kotlin `HydrationReminderScheduleTest`. Uses UTC instants so
/// wall-clock arithmetic is deterministic across time zones.
DateTime at({int day = 1, required int hour, required int minute}) =>
    DateTime.utc(2026, 6, day, hour, minute);

void main() {
  group('calculateNextHydrationReminderTime', () {
    test('inside active hours adds interval', () {
      final next = calculateNextHydrationReminderTime(
        at(hour: 10, minute: 0),
        const HydrationReminderConfig(intervalMinutes: 90),
      );

      expect(next, at(hour: 11, minute: 30));
    });

    test('before active hours waits until active start plus interval', () {
      final next = calculateNextHydrationReminderTime(
        at(hour: 5, minute: 0),
        const HydrationReminderConfig(intervalMinutes: 120),
      );

      expect(next, at(hour: 9, minute: 0));
    });

    test('crossing active end moves to next active start plus interval', () {
      final next = calculateNextHydrationReminderTime(
        at(hour: 22, minute: 30),
        const HydrationReminderConfig(intervalMinutes: 60),
      );

      expect(next, at(day: 2, hour: 8, minute: 0));
    });

    test('goal met schedules tomorrow after active start plus interval', () {
      final next = calculateNextHydrationReminderTime(
        at(hour: 12, minute: 0),
        const HydrationReminderConfig(intervalMinutes: 120),
        dailyGoalMet: true,
      );

      expect(next, at(day: 2, hour: 9, minute: 0));
    });
  });

  group('isWithinHydrationReminderActiveHours', () {
    test('overnight window includes times after midnight before end', () {
      const config = HydrationReminderConfig(
        activeStartTime: LocalTime(7, 0),
        activeEndTime: LocalTime(1, 0),
      );

      expect(
        isWithinHydrationReminderActiveHours(const LocalTime(23, 0), config),
        isTrue,
      );
      expect(
        isWithinHydrationReminderActiveHours(const LocalTime(0, 30), config),
        isTrue,
      );
      expect(
        isWithinHydrationReminderActiveHours(const LocalTime(2, 0), config),
        isFalse,
      );
    });

    test('equal start and end means always active', () {
      const config = HydrationReminderConfig(
        activeStartTime: LocalTime(0, 0),
        activeEndTime: LocalTime(0, 0),
      );

      expect(
        isWithinHydrationReminderActiveHours(const LocalTime(3, 0), config),
        isTrue,
      );
    });
  });
}
