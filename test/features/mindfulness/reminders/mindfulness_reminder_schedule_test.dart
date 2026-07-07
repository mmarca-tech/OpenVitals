import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/core/time/local_date.dart';
import 'package:openvitals/domain/model/mindfulness_reminder_config.dart';
import 'package:openvitals/features/mindfulness/reminders/mindfulness_reminder_schedule.dart';

/// Ported from the Kotlin `MindfulnessReminderScheduleTest`.
DateTime at({int day = 1, required int hour, required int minute}) =>
    DateTime.utc(2026, 6, day, hour, minute);

void main() {
  group('calculateNextMindfulnessReminderTime', () {
    test('before configured time schedules today', () {
      final next = calculateNextMindfulnessReminderTime(
        at(hour: 12, minute: 0),
        const MindfulnessReminderConfig(reminderTime: LocalTime(18, 0)),
      );

      expect(next, at(hour: 18, minute: 0));
    });

    test('after configured time schedules tomorrow', () {
      final next = calculateNextMindfulnessReminderTime(
        at(hour: 19, minute: 0),
        const MindfulnessReminderConfig(reminderTime: LocalTime(18, 0)),
      );

      expect(next, at(day: 2, hour: 18, minute: 0));
    });

    test('goal met schedules tomorrow even when time is still ahead', () {
      final next = calculateNextMindfulnessReminderTime(
        at(hour: 12, minute: 0),
        const MindfulnessReminderConfig(reminderTime: LocalTime(18, 0)),
        dailyGoalMet: true,
      );

      expect(next, at(day: 2, hour: 18, minute: 0));
    });
  });
}
