import '../../../core/result/result.dart';
import '../../../domain/model/comaps_navigation.dart';

/// Live navigation context borrowed from CoMaps while OpenVitals records.
///
/// The ownership boundary is the whole point of this feature: **CoMaps plans and
/// navigates; OpenVitals records.** Nothing here can start, stop or steer a
/// route — it reads what CoMaps is already doing, and nothing it returns is ever
/// written to Health Connect.
abstract interface class CoMapsNavigationRepository {
  /// What CoMaps can tell us right now. Every outcome is a [CoMapsNavigationState],
  /// including the unavailable ones — an `Err` here means the *bridge* failed,
  /// not that guidance is unavailable, which is an ordinary answer.
  Future<Result<CoMapsNavigationState>> readLive();

  Future<Result<bool>> hasPermission();

  /// Asks for `app.comaps.permission.READ_NAVIGATION_DATA`. False when the user
  /// refuses, and also when CoMaps is not installed — the permission is
  /// CoMaps', and does not exist without it.
  Future<Result<bool>> requestPermission();

  Future<Result<bool>> canLaunchCoMaps();

  /// Opens CoMaps so the user can plan a route, centred on their last fix when
  /// there is one.
  Future<Result<bool>> launchForPlanning({double? latitude, double? longitude});

  /// The guidance sampled during a recording, kept against the saved activity.
  /// App-local history only.
  Future<Result<void>> saveSamples(
    String activityId,
    List<CoMapsNavigationSnapshot> samples,
  );

  Future<Result<List<CoMapsNavigationSnapshot>>> loadSamples(String activityId);
}
