import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/core/period/period_titles.dart';
import 'package:openvitals/core/period/time_range.dart';
import 'package:openvitals/core/time/local_date.dart';

void main() {
  final today = LocalDate(2026, 6, 10);

  test('day titles use relative labels for today and yesterday', () {
    expect(
      periodTitle(TimeRange.day, DatePeriod(today, today), today: today),
      'Today',
    );
    expect(
      periodTitle(
        TimeRange.day,
        DatePeriod(today.minusDays(1), today.minusDays(1)),
        today: today,
      ),
      'Yesterday',
    );
  });

  test('period titles use current labels when period contains today', () {
    expect(
      periodTitle(
        TimeRange.week,
        DatePeriod(LocalDate(2026, 6, 8), today),
        today: today,
      ),
      'This week',
    );
    expect(
      periodTitle(
        TimeRange.month,
        DatePeriod(LocalDate(2026, 6, 1), today),
        today: today,
      ),
      'This month',
    );
    expect(
      periodTitle(
        TimeRange.year,
        DatePeriod(LocalDate(2026, 1, 1), today),
        today: today,
      ),
      'This year',
    );
  });
}
