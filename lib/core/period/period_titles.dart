import 'package:intl/intl.dart';

import '../time/local_date.dart';
import 'time_range.dart';

final DateFormat _dateFormatter = DateFormat('EEE d MMM');
final DateFormat _monthFormatter = DateFormat('LLLL yyyy');
final DateFormat _yearFormatter = DateFormat('yyyy');

DateTime _asDateTime(LocalDate date) => DateTime(date.year, date.month, date.day);

/// The human-readable title for a period. Literal English strings match the
/// Kotlin source; localization is handled in the l10n phase.
String periodTitle(
  TimeRange range,
  DatePeriod period, {
  LocalDate? today,
}) {
  final resolvedToday = today ?? LocalDate.now();
  switch (range) {
    case TimeRange.day:
      if (period.start == resolvedToday) return 'Today';
      if (period.start == resolvedToday.minusDays(1)) return 'Yesterday';
      return _dateFormatter.format(_asDateTime(period.start));
    case TimeRange.week:
      if (resolvedToday.isBetween(period.start, period.end)) {
        return 'This week';
      }
      return 'Week of ${_dateFormatter.format(_asDateTime(period.start))}';
    case TimeRange.month:
      if (period.end == resolvedToday) return 'This month';
      return _monthFormatter.format(_asDateTime(period.start));
    case TimeRange.year:
      if (period.end == resolvedToday) return 'This year';
      return _yearFormatter.format(_asDateTime(period.start));
  }
}
