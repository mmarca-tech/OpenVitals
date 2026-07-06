/// Stub of the insights intensity-minutes types referenced by `DashboardData`
/// (`DashboardWeeklyIntensityMinutes`). The full intensity-minutes calculation
/// lives outside the model layer and is ported separately.
const int defaultWeeklyIntensityMinutesTarget = 150;

enum IntensityMinutesConfidence {
  high('HIGH'),
  medium('MEDIUM'),
  low('LOW'),
  noData('NO_DATA');

  const IntensityMinutesConfidence(this.storageName);

  /// Original Kotlin `.name` used for persistence round-trips.
  final String storageName;

  static IntensityMinutesConfidence? fromStorage(String value) {
    for (final entry in values) {
      if (entry.storageName == value) return entry;
    }
    return null;
  }
}
