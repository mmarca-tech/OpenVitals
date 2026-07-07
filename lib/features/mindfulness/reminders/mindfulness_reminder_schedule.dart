import '../../../core/time/local_date.dart';
import '../../../domain/model/mindfulness_reminder_config.dart';

/// Pure scheduling math for the daily mindfulness reminder, ported 1:1 from the
/// Kotlin `MindfulnessReminderSchedule.kt`.
///
/// Device-independent: operates on plain [DateTime]s (the port's stand-in for
/// `java.time.ZonedDateTime`) and the [MindfulnessReminderConfig] value type.

/// The next moment the mindfulness reminder should fire, given [now]/[config].
///
/// The reminder is a single daily time. If that time is still ahead today (and
/// the goal is not already met) it fires today; otherwise it rolls to tomorrow.
DateTime calculateNextMindfulnessReminderTime(
  DateTime now,
  MindfulnessReminderConfig config, {
  bool dailyGoalMet = false,
}) {
  final reminderTime = config.normalized().reminderTime;
  final todayReminder = _atTime(now, _dateOf(now), reminderTime);
  if (!dailyGoalMet && todayReminder.isAfter(now)) {
    return todayReminder;
  }
  return _atTime(now, _dateOf(now).plusDays(1), reminderTime);
}

LocalDate _dateOf(DateTime moment) =>
    LocalDate(moment.year, moment.month, moment.day);

DateTime _atTime(DateTime reference, LocalDate date, LocalTime time) =>
    reference.isUtc
        ? DateTime.utc(date.year, date.month, date.day, time.hour, time.minute)
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
