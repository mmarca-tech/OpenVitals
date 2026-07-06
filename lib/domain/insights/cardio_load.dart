/// Stub of the insights `CardioLoadConfidence` enum referenced by
/// `DashboardData` (`DashboardWeeklyCardioLoad`). The full CardioLoad insight
/// calculation lives outside the model layer and is ported separately.
enum CardioLoadConfidence {
  high('HIGH'),
  medium('MEDIUM'),
  low('LOW'),
  noData('NO_DATA');

  const CardioLoadConfidence(this.storageName);

  /// Original Kotlin `.name` used for persistence round-trips.
  final String storageName;

  static CardioLoadConfidence? fromStorage(String value) {
    for (final entry in values) {
      if (entry.storageName == value) return entry;
    }
    return null;
  }
}
