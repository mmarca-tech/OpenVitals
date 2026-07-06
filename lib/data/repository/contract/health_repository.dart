import '../../../domain/model/health_connect_availability.dart';
import '../../../domain/model/permission_grant_mode.dart';

/// Port of the Kotlin `HealthRepository` contract.
///
/// The stable permission API the feature/state layers depend on. Permissions
/// are AndroidX Health Connect permission strings (see
/// `lib/health/health_permissions.dart`).
///
/// Note: the Kotlin `permissionContract()` returns an Android
/// `ActivityResultContract`; the Dart `health` package instead requests
/// authorization imperatively, so that method is replaced by
/// [requestPermissions].
abstract interface class HealthRepository {
  HealthConnectAvailability availability();

  /// Requests OS authorization for [permissions]; returns whether the request
  /// completed successfully. Replaces the Kotlin `permissionContract()`.
  Future<bool> requestPermissions(Set<String> permissions);

  Set<String> get phase1Permissions;
  Set<String> get minimumOnboardingPermissions;
  Set<String> get phase2Permissions;
  Set<String> get phase3Permissions;
  Set<String> get phase4Permissions;
  Set<String> get corePermissions;
  Set<String> get routePermissions;
  Set<String> get activityWritePermissions;
  Set<String> get heartPermissions;
  Set<String> get bodyPermissions;
  Set<String> get bodyWritePermissions;
  Set<String> get activityExtrasPermissions;
  Set<String> get nutritionHydrationPermissions;
  Set<String> get hydrationWritePermissions;
  Set<String> get mindfulnessPermissions;
  Set<String> get mindfulnessWritePermissions;
  Set<String> get additionalDataAccessPermissions;
  Set<String> get vitalsPermissions;
  Set<String> get vitalsWritePermissions;
  Set<String> get dataImportWritePermissions;
  Set<String> get cyclePermissions;
  Set<String> get manualOnlyPermissions;
  Set<String> get requestableWritePermissions;
  Set<String> get onboardingPermissions;
  Set<String> get allPermissions;
  Set<String> get managedPermissions;

  PermissionGrantMode grantModeFor(String permission);

  bool isMindfulnessAvailable();

  Future<Set<String>> grantedPermissions();

  Future<Set<String>> missingPhase1();
}
