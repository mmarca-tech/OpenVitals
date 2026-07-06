import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/core/period/period_calculations.dart';
import 'package:openvitals/core/period/period_selection.dart';
import 'package:openvitals/core/period/time_range.dart';
import 'package:openvitals/core/time/local_date.dart';

void main() {
  final today = LocalDate(2026, 4, 26);

  test('selectRange keeps future selected date capped at today', () {
    final selection = PeriodSelection(TimeRange.week, today.plusDays(3));

    final updated = selection.selectRange(TimeRange.month, today: today);

    expect(updated.selectedRange, TimeRange.month);
    expect(updated.selectedDate, today);
  });

  test('previousPeriod moves by selected range', () {
    final selection = PeriodSelection(TimeRange.month, LocalDate(2026, 4, 15));

    expect(selection.previousPeriod().selectedDate, LocalDate(2026, 3, 15));
  });

  test('nextPeriod does not move beyond current period', () {
    final selection = PeriodSelection(TimeRange.week, today);

    expect(selection.nextPeriod(today: today), selection);
  });

  test('nextPeriod moves when the next period is not in the future', () {
    final selection = PeriodSelection(TimeRange.week, today.plusWeeks(-2));

    final updated = selection.nextPeriod(today: today);

    expect(updated.selectedDate, today.plusWeeks(-1));
    expect(updated.period(today: today).end.isAfter(today), isFalse);
  });

  test('previousPeriodFor returns previous calendar period', () {
    final period = previousPeriodFor(
      TimeRange.month,
      LocalDate(2026, 4, 15),
      today: today,
    );

    expect(period.start, LocalDate(2026, 3, 1));
    expect(period.end, LocalDate(2026, 3, 31));
  });

  test('displayPeriodFor keeps full Monday to Sunday week mid week', () {
    final wednesday = LocalDate(2026, 5, 27);
    final period = displayPeriodFor(
      TimeRange.week,
      wednesday,
      today: wednesday,
      weekPeriodMode: WeekPeriodMode.mondayToSunday,
    );

    expect(period.start, LocalDate(2026, 5, 25));
    expect(period.end, LocalDate(2026, 5, 31));
  });

  test('displayPeriodFor supports rolling last seven days', () {
    final period = displayPeriodFor(
      TimeRange.week,
      today,
      today: today,
      weekPeriodMode: WeekPeriodMode.last7Days,
    );

    expect(period.start, today.minusDays(6));
    expect(period.end, today);
  });
}
