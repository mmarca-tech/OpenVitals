import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/presentation/command_state.dart';
import '../../../core/presentation/screen_error.dart';
import '../../../core/result/result.dart';
import '../../../data/prefs/preferences_repository.dart';
import '../../../di/providers.dart';
import '../../../domain/health/health_permissions.dart';
import '../../../domain/model/health_connect_availability.dart';
import '../../../domain/model/onboarding_permission_category.dart';
import '../../../domain/preferences/app_language.dart';
import '../../../ui/components/health_connect_gate.dart';
import 'onboarding_display.dart';

// The rows onboarding offers are a domain description of what the app can ask
// for; the screen renders them straight out of here.
export '../../../domain/model/onboarding_permission_category.dart';
export 'onboarding_display.dart';

part 'onboarding_view_model.freezed.dart';

/// The display of a screen that has not read the catalog yet: no rows, and
/// nothing granted (so the primary action is still the grant, not "Continue").
const OnboardingDisplay _emptyDisplay = OnboardingDisplay(
  rows: <OnboardingCategoryRow>[],
  missingRequired: <String>{},
  requiredGranted: false,
);

/// The Riverpod port of the Kotlin `OnboardingUiState`.
///
/// The phased-grant booleans of the Kotlin state — and the per-row granted
/// counts the screen used to fold on every rebuild — are precomputed into
/// [display] at load time.
@freezed
abstract class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(HealthConnectAvailability.available)
    HealthConnectAvailability availability,
    @Default(<String>{}) Set<String> grantedPermissions,

    /// Device feature AND user opt-in: whether the mindfulness row is offered
    /// and its permissions may be requested.
    @Default(false) bool mindfulnessAvailable,

    /// The device's answer alone. Drives whether the opt-in switch is shown at
    /// all — there is no point offering it on a phone that has no mindfulness.
    @Default(false) bool mindfulnessSupportedByDevice,

    /// The switch's own position, read from (and written to) preferences.
    @Default(false) bool mindfulnessOptIn,
    @Default(true) bool isCheckingPermissions,
    @Default(_emptyDisplay) OnboardingDisplay display,

    /// The permission-grant flow: the runtime dialog, and the trip to the
    /// Health Connect page a non-requestable permission needs. One user action,
    /// one command.
    @Default(CommandState<void>.idle()) CommandState<void> grant,

    /// Why the initial availability + granted-permission read failed, if it
    /// did. The screen degrades to the (empty) permission flow rather than
    /// hanging on the loader, which is what the thrown failure used to do.
    ScreenError? error,
  }) = _OnboardingState;
}

/// The Riverpod port of the Kotlin `OnboardingViewModel`.
///
/// Manual [Notifier] (no codegen): [build] kicks off [checkState], which reads
/// Health Connect availability + the currently-granted permissions. The screen
/// drives [requestPermissions] for a phase/category, [openHealthConnectSettings]
/// for a manual-only one, [selectLanguage] for the header dropdown, and
/// [completeOnboarding] to persist the onboarding-complete + privacy-policy
/// prefs so the app routes to the dashboard on next launch.
class OnboardingViewModel extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    Future.microtask(() {
      if (ref.mounted) checkState();
    });
    return const OnboardingState();
  }

  PreferencesRepository get _prefs => ref.read(preferencesRepositoryProvider);

  /// Whether the automatic trip to the Health Connect page has already happened.
  ///
  /// It must happen at most once per visit to the screen. [refreshGrantedPermissions]
  /// runs on every resume, so an unlatched auto-open would fire again the instant
  /// the user came back from Health Connect — and again after that, forever.
  bool _autoOpenedSettings = false;

  /// The rows, the one required request and the full offer — assembled from the
  /// device's permission catalog, with the mindfulness row present only where
  /// mindfulness exists *and* the user opted in
  /// (see [ReadOnboardingPermissionCatalogUseCase]).
  OnboardingPermissionCatalog get _catalog =>
      _catalogFor(mindfulnessAvailable: state.mindfulnessAvailable);

  OnboardingPermissionCatalog _catalogFor({
    required bool mindfulnessAvailable,
  }) =>
      ref.read(readOnboardingPermissionCatalogUseCaseProvider)(
        mindfulnessAvailable: mindfulnessAvailable,
      );

  Set<String> get requiredOnboardingPermissions => _catalog.requiredPermissions;

  Set<String> get onboardingPermissions => _catalog.allPermissions;

  /// The grantable permission groups, filtered to the non-empty ones (mirrors
  /// the Kotlin `permissionCategories.filter { it.permissions.isNotEmpty() }`).
  List<OnboardingPermissionCategory> get permissionCategories =>
      _catalog.categories;

  Future<void> checkState() async {
    // Availability is resolved from the platform (async plugin boundary) rather
    // than read from the still-default cache, and nothing else is asked of a
    // device that has no Health Connect — see [CheckOnboardingStateUseCase].
    final result = await ref.read(checkOnboardingStateUseCaseProvider)();
    if (!ref.mounted) return;
    switch (result) {
      case Ok(:final value):
        state = OnboardingState(
          availability: value.availability,
          grantedPermissions: value.grantedPermissions,
          mindfulnessAvailable: value.mindfulnessAvailable,
          mindfulnessSupportedByDevice: value.mindfulnessSupportedByDevice,
          mindfulnessOptIn: _prefs.healthConnectMindfulnessEnabled,
          isCheckingPermissions: false,
          display: buildOnboardingDisplay(
            _catalogFor(mindfulnessAvailable: value.mindfulnessAvailable),
            value.grantedPermissions,
          ),
        );
      case Err(:final failure):
        // The read that failed is the one that says what is granted, so the
        // rows fall back to "nothing is". The loader is dropped either way: a
        // thrown failure used to leave it spinning for good.
        state = state.copyWith(
          isCheckingPermissions: false,
          display: buildOnboardingDisplay(_catalog, const <String>{}),
          error: failure.toScreenError(
            fallback: 'Unable to check Health Connect.',
          ),
        );
    }
  }

  /// Re-reads the granted permission set without the full-screen loader. Called
  /// when the app returns to the foreground (e.g. after the user granted access
  /// manually in the Health Connect settings page), so category rows flip to
  /// "Granted" without needing an app restart.
  Future<void> refreshGrantedPermissions() async {
    if (state.availability != HealthConnectAvailability.available) return;
    final result =
        await ref.read(loadGrantedHealthPermissionsUseCaseProvider)();
    if (!ref.mounted) return;
    // A failed re-read is not worth a message: the rows keep the last set they
    // knew about, exactly as they would have on an unchanged one.
    if (result case Ok(:final value) when value != state.grantedPermissions) {
      state = state.copyWith(
        grantedPermissions: value,
        display: buildOnboardingDisplay(_catalog, value),
      );
      ref.invalidate(grantedHealthPermissionsProvider);
    }
  }

  /// Requests [permissions] then re-reads the granted set (Kotlin
  /// `onPermissionsResult`). No-op for an empty request.
  ///
  /// If the runtime dialog could not grant ANY of the requested permissions —
  /// which happens when Health Connect reports them as non-requestable (planned
  /// exercise, exercise routes, background/history access) — this falls back to
  /// opening the Health Connect page so the user can toggle them manually
  /// (mirrors the Kotlin "Open required Health Connect permissions" action).
  Future<void> requestPermissions(Set<String> permissions) async {
    if (permissions.isEmpty) return;
    state = state.copyWith(grant: const CommandState<void>.running());
    // Whether the dialog achieved anything is not something it will say — see
    // [GrantOnboardingPermissionsUseCase], which works it out by comparing the
    // granted set on either side of the request.
    final result =
        await ref.read(grantOnboardingPermissionsUseCaseProvider)(permissions);
    if (!ref.mounted) return;
    switch (result) {
      case Ok(:final value):
        state = state.copyWith(
          grantedPermissions: value.grantedPermissions,
          display: buildOnboardingDisplay(_catalog, value.grantedPermissions),
          grant: const CommandState<void>.success(null),
        );
        // Keep the shared gate providers fresh for screens shown after
        // onboarding.
        ref.invalidate(grantedHealthPermissionsProvider);

        // Opened here rather than inside the use case so the new granted set is
        // already published before the user disappears into Health Connect's UI.
        if (value.needsManualGrant) {
          _autoOpenedSettings = true;
          await openHealthConnectSettings();
        } else {
          await _maybeAutoOpenSettings(value.grantedPermissions);
        }
      case Err(:final failure):
        state = state.copyWith(
          grant: CommandState<void>.failure(
            failure.toScreenError(fallback: 'Unable to request permissions.'),
          ),
        );
    }
  }

  /// Sends the user to the Health Connect page once, if anything in the
  /// "additional data access" group is still outstanding after the dialog.
  ///
  /// Exercise routes cannot be granted by the runtime dialog at all, and no API
  /// says whether a given provider's dialog will grant history or background
  /// reads — so the only way to finish those is the settings page, and the only
  /// moment the user is expecting to be sent there is right after they granted
  /// everything else.
  Future<void> _maybeAutoOpenSettings(Set<String> granted) async {
    if (_autoOpenedSettings) return;
    final outstanding = _additionalAccessPermissions.difference(granted);
    if (outstanding.isEmpty) return;
    _autoOpenedSettings = true;
    await openHealthConnectSettings();
  }

  /// The permissions behind the "additional data access" row: exercise routes
  /// plus whichever of history / background reads this device supports.
  Set<String> get _additionalAccessPermissions => _catalog.categories
      .where((category) => category.id == 'additional_data_access')
      .expand((category) => category.permissions)
      .toSet();

  /// Turns the mindfulness opt-in on or off from the onboarding screen.
  ///
  /// The preference is an *input* to the resolved feature flags — see the crash
  /// it guards against in `HealthConnectNativeDataSource.resolveFeatureFlags` —
  /// so the entire taxonomy is stale the moment it flips. [checkState] goes
  /// through `refreshAvailability()`, which re-resolves the flags and the
  /// device-supported permission set before the catalog is rebuilt; the same
  /// reasoning as `SettingsViewModel.setHealthConnectMindfulnessEnabled`.
  Future<void> setMindfulnessOptIn(bool enabled) async {
    _prefs.healthConnectMindfulnessEnabled = enabled;
    state = state.copyWith(mindfulnessOptIn: enabled);
    ref
      ..invalidate(healthConnectAvailabilityProvider)
      ..invalidate(grantedHealthPermissionsProvider);
    await checkState();
  }

  /// Opens the Health Connect permission page — the only way to grant a
  /// permission the runtime dialog refuses to ask for (exercise routes,
  /// background/history access).
  Future<void> openHealthConnectSettings() async {
    state = state.copyWith(grant: const CommandState<void>.running());
    final result = await ref.read(openHealthConnectSettingsUseCaseProvider)();
    if (!ref.mounted) return;
    state = state.copyWith(
      grant: switch (result) {
        Ok() => const CommandState<void>.success(null),
        Err(:final failure) => CommandState<void>.failure(
            failure.toScreenError(
              fallback: 'Unable to open Health Connect.',
            ),
          ),
      },
    );
  }

  /// The screen has shown the outcome of the grant flow; put the command back to
  /// idle so re-entering the route cannot replay it.
  void clearGrantCommand() {
    if (state.grant is! CommandIdle<void>) {
      state = state.copyWith(grant: const CommandState<void>.idle());
    }
  }

  /// Persists the app language. Changing it re-renders the whole app:
  /// `appLanguageProvider` drives `MaterialApp.locale` in app.dart.
  void selectLanguage(AppLanguage language) => _prefs.appLanguage = language;

  /// Persists the privacy-policy acceptance + onboarding-complete prefs so the
  /// router picks the dashboard as the start destination next launch.
  void completeOnboarding() {
    _prefs
      ..acceptedPrivacyPolicyVersion =
          PreferencesRepository.currentPrivacyPolicyVersion
      ..privacyPolicyAcceptedAtMillis = DateTime.now().millisecondsSinceEpoch
      // Records WHICH permission set was asked for, so a future widening of it
      // can send this user back through onboarding rather than silently never
      // asking them — see [PreferencesRepository.lastPromptedPermissionSetVersion].
      ..lastPromptedPermissionSetVersion =
          HealthPermissionService.PERMISSION_SET_VERSION
      ..onboardingDone = true;
  }
}

/// The onboarding state provider — a manually-declared [NotifierProvider].
final onboardingProvider =
    NotifierProvider<OnboardingViewModel, OnboardingState>(
  OnboardingViewModel.new,
);
