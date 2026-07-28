import '../../core/result/result.dart';
import '../../data/repository/contract/health_repository.dart';
import '../model/health_connect_availability.dart';

/// Whether the permissions the app cannot work without have been granted.
///
/// Takes the availability rather than reading it, because the caller has already
/// had to resolve it asynchronously and the answer must be the same one: a device
/// where Health Connect is missing or out of date has granted nothing, and asking
/// it for its granted set would be a platform call whose answer we already know.
///
/// The set checked is the app's own definition of usable — it is the same set
/// onboarding refuses to finish without ([HealthRepository.requiredOnboardingPermissions])
/// — so this is what decides whether a screen shows data or shows the permission
/// gate. Since onboarding now hard-blocks on that whole set, anyone who completed
/// it passes here; the ones this catches are users upgrading from a build whose
/// onboarding asked for less.
class CheckMinimumHealthPermissionsUseCase {
  const CheckMinimumHealthPermissionsUseCase(this._healthRepository);

  final HealthRepository _healthRepository;

  Future<Result<bool>> call(HealthConnectAvailability availability) async {
    final granted = availability == HealthConnectAvailability.available
        ? await _healthRepository.grantedPermissions()
        : const Ok(<String>{});
    return granted.map((granted) => _healthRepository
        .requiredOnboardingPermissions
        .every(granted.contains));
  }
}
