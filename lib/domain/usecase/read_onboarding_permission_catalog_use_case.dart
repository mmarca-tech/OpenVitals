import '../../data/repository/contract/health_repository.dart';
import '../model/onboarding_permission_category.dart';

/// Assembles the permission rows onboarding offers — **synchronously**, because
/// they are a static description of what the app can ask for, not a question for
/// the platform.
///
/// The grouping is the point. Health Connect grants permissions one record type at
/// a time, which is unanswerable as a list of forty toggles; onboarding instead
/// asks for a handful of *reasons* ("heart & recovery", "nutrition & hydration"),
/// each of which expands to the permissions that reason needs.
///
/// Most rows are required: onboarding asks for all of them in one request and
/// will not finish until they are granted. Four are not, and each for its own
/// reason:
///
/// * Mindfulness is an optional Health Connect feature *and* an opt-in, because
///   some providers crash their own permission UI when asked for it — hence
///   [mindfulnessAvailable] (device AND user) as the input. It is never part of
///   the one big required request; its row grants it on its own, so a provider
///   that cannot face it takes nothing else down with it.
/// * Cycle tracking is sensitive enough that a first-run all-or-nothing prompt is
///   the wrong place to ask, so it stays a row the user chooses to tap.
/// * Exercise routes cannot be granted by the runtime dialog at all. They ride
///   along with the "additional data access" row but are flagged as manual, so the
///   screen can send the user to the Health Connect page instead of asking for
///   something the dialog will silently ignore.
/// * History and background access share that row because there is no API that
///   says whether a given provider's dialog will grant them; requiring them would
///   risk an onboarding nobody can leave.
///
/// An empty group is dropped rather than rendered as a row that grants nothing.
class ReadOnboardingPermissionCatalogUseCase {
  const ReadOnboardingPermissionCatalogUseCase(this._healthRepository);

  final HealthRepository _healthRepository;

  OnboardingPermissionCatalog call({required bool mindfulnessAvailable}) {
    final repo = _healthRepository;
    final categories = <OnboardingPermissionCategory>[
      OnboardingPermissionCategory(
        id: 'activity_sleep',
        permissions: repo.corePermissions,
        isRequired: true,
      ),
      OnboardingPermissionCategory(
        id: 'heart_recovery',
        permissions: repo.heartPermissions,
        isRequired: true,
      ),
      OnboardingPermissionCategory(
        id: 'vitals',
        permissions: repo.vitalsPermissions,
        isRequired: true,
      ),
      OnboardingPermissionCategory(
        id: 'body',
        permissions: repo.bodyPermissions,
        isRequired: true,
      ),
      OnboardingPermissionCategory(
        id: 'activity_extras',
        permissions: repo.activityExtrasPermissions,
        isRequired: true,
      ),
      OnboardingPermissionCategory(
        id: 'nutrition_hydration',
        permissions: repo.nutritionHydrationPermissions,
        isRequired: true,
      ),
      // The write rows carry mindfulness and cycle writes when those are in
      // play, so they are shown minus whatever the required request excludes —
      // otherwise a row could never reach "Granted" and the count under it would
      // be a lie.
      OnboardingPermissionCategory(
        id: 'manual_entry_write',
        permissions: repo.requestableWritePermissions
            .difference(repo.mindfulnessWritePermissions),
        isRequired: true,
      ),
      OnboardingPermissionCategory(
        id: 'data_import_write',
        permissions: repo.dataImportWritePermissions
            .difference(repo.mindfulnessWritePermissions)
            .difference(repo.cycleWritePermissions),
        isRequired: true,
      ),
      // Read AND write together: the opt-in is one decision, and splitting it
      // across two rows would ask the user to make it twice.
      OnboardingPermissionCategory(
        id: 'mindfulness',
        permissions: {
          ...repo.mindfulnessPermissions,
          ...repo.mindfulnessWritePermissions,
        },
        available: mindfulnessAvailable,
      ),
      // Access past data (history) + access data in the background can be
      // requested directly via the dialog; exercise-route access needs the
      // "Always" toggle in Health Connect settings (opened via the fallback).
      // Mirrors the Kotlin OnboardingViewModel's additionalDataAccess +
      // routePermissions category, with routes flagged as manual-only.
      OnboardingPermissionCategory(
        id: 'additional_data_access',
        permissions: {
          ...repo.additionalDataAccessPermissions,
          ...repo.routePermissions,
        },
        manualPermissions: repo.routePermissions,
      ),
      OnboardingPermissionCategory(
        id: 'cycle_tracking',
        permissions: {
          ...repo.cyclePermissions,
          ...repo.cycleWritePermissions,
        },
      ),
    ].where((category) => category.permissions.isNotEmpty).toList();

    return OnboardingPermissionCatalog(
      categories: categories,
      requiredPermissions: repo.requiredOnboardingPermissions,
      allPermissions: repo.onboardingPermissions,
    );
  }
}
