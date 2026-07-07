import '../../../core/time/local_date.dart';
import '../../../domain/model/hydration_reminder_config.dart';

/// Pure scheduling math for hydration reminders, ported 1:1 from the Kotlin
/// `HydrationReminderSchedule.kt`.
///
/// Everything here is device-independent: it operates on plain [DateTime]s (the
/// Dart port's stand-in for `java.time.ZonedDateTime` — the instant carries its
/// own zone via [DateTime.isUtc]) and the [HydrationReminderConfig] value type.
/// The wall-clock arithmetic preserves the reference instant's zone so results
/// stay stable across the actual alarm plumbing in [HydrationReminderController].

/// The next moment a hydration reminder should fire, given [now] and [config].
///
/// When [dailyGoalMet] is true the next reminder is pushed to tomorrow's active
/// window (the user already hit their goal today, so we stop nagging).
DateTime calculateNextHydrationReminderTime(
  DateTime now,
  HydrationReminderConfig config, {
  bool dailyGoalMet = false,
}) {
  final normalized = config.normalized();
  final interval = Duration(minutes: normalized.intervalMinutes);

  if (dailyGoalMet) {
    return _atTime(now, _dateOf(now).plusDays(1), normalized.activeStartTime)
        .add(interval);
  }

  if (!isWithinHydrationReminderActiveHours(_timeOf(now), normalized)) {
    return _nextActiveStartAfter(now, normalized).add(interval);
  }

  final candidate = now.add(interval);
  if (isWithinHydrationReminderActiveHours(_timeOf(candidate), normalized)) {
    return candidate;
  }
  return _nextActiveStartAfter(candidate, normalized).add(interval);
}

/// Whether [time] falls inside the config's active window. The window may wrap
/// past midnight (end before start), matching the Kotlin implementation.
bool isWithinHydrationReminderActiveHours(
  LocalTime time,
  HydrationReminderConfig config,
) {
  final start = config.activeStartTime.minuteOfDay;
  final end = config.activeEndTime.minuteOfDay;
  if (start == end) return true;
  final value = time.minuteOfDay;
  if (end > start) {
    return value >= start && value < end;
  }
  return value >= start || value < end;
}

DateTime _nextActiveStartAfter(DateTime moment, HydrationReminderConfig config) {
  final todayStart = _atTime(moment, _dateOf(moment), config.activeStartTime);
  if (todayStart.isAfter(moment)) return todayStart;
  return _atTime(moment, _dateOf(moment).plusDays(1), config.activeStartTime);
}

LocalDate _dateOf(DateTime moment) =>
    LocalDate(moment.year, moment.month, moment.day);

LocalTime _timeOf(DateTime moment) => LocalTime(moment.hour, moment.minute);

/// Builds an instant at [date]/[time] in the same zone (UTC vs local) as
/// [reference], mirroring `LocalDate.atTime(...).atZone(reference.zone)`.
DateTime _atTime(DateTime reference, LocalDate date, LocalTime time) =>
    reference.isUtc
        ? DateTime.utc(date.year, date.month, date.day, time.hour, time.minute)
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
