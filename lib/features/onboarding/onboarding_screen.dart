import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/health_connect_availability.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/components/loading_state.dart';
import '../../ui/components/ov_card.dart';
import 'onboarding_notifier.dart';

/// Onboarding flow, shown as the start destination when onboarding is not yet
/// complete. Rendered full-screen outside the adaptive shell.
///
/// Port of the Kotlin `OnboardingScreen`: a Health Connect availability check,
/// a one-tap "grant all" of the required (minimum) permissions, per-category
/// grant rows, and a Continue action that persists the onboarding-complete pref
/// (via [OnboardingNotifier.completeOnboarding]) before invoking
/// [onOnboardingComplete] so the app routes on to the dashboard.
///
/// All copy is localized one-to-one from the Kotlin `strings.xml` onboarding_*
/// resources via [AppLocalizations].
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key, this.onOnboardingComplete});

  final VoidCallback? onOnboardingComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingNotifierProvider);
    final notifier = ref.read(onboardingNotifierProvider.notifier);

    if (state.isCheckingPermissions) {
      return const Scaffold(body: FullScreenLoading());
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: _OnboardingContent(
            state: state,
            notifier: notifier,
            onComplete: () {
              notifier.completeOnboarding();
              onOnboardingComplete?.call();
            },
          ),
        ),
      ),
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent({
    required this.state,
    required this.notifier,
    required this.onComplete,
  });

  final OnboardingState state;
  final OnboardingNotifier notifier;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.appName,
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.onboardingTagline,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    if (state.availability != HealthConnectAvailability.available) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 24),
          _UnavailableCard(availability: state.availability),
        ],
      );
    }

    final minimum = notifier.minimumOnboardingPermissions;
    final onboardingPermissions = notifier.onboardingPermissions;
    final granted = state.grantedPermissions;
    final missingMinimum = minimum.difference(granted);
    final minimumGranted = missingMinimum.isEmpty;
    final missingOptional =
        onboardingPermissions.difference(granted).difference(minimum);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 24),
        _FeatureCard(
          icon: Icons.lock_outline,
          title: l10n.onboardingPrivacyTitle,
          body: l10n.onboardingPrivacyBody,
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          icon: Icons.health_and_safety_outlined,
          title: l10n.onboardingHealthConnectTitle,
          body: l10n.onboardingHealthConnectBody,
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          icon: Icons.info_outline,
          title: l10n.healthDisclaimerTitle,
          body: l10n.healthDisclaimerBody,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: minimumGranted
              ? onComplete
              : () => notifier.requestPermissions(missingMinimum),
          child: Text(minimumGranted ? l10n.actionContinue : l10n.onboardingGrantAll),
        ),
        if (minimumGranted && missingOptional.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonal(
              onPressed: () => notifier.requestPermissions(missingOptional),
              child: Text(l10n.onboardingGrantRemaining),
            ),
          ),
        if (!minimumGranted)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.onboardingCoreRequired,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 24),
        Text(
          l10n.onboardingPermissionsHeader,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        for (final category in notifier.permissionCategories)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PermissionCategoryRow(
              category: category,
              granted: granted,
              onGrant: () => notifier.requestPermissions(
                category.permissions.difference(granted),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OpenVitalsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCategoryRow extends StatelessWidget {
  const _PermissionCategoryRow({
    required this.category,
    required this.granted,
    required this.onGrant,
  });

  final OnboardingPermissionCategory category;
  final Set<String> granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final total = category.permissions.length;
    final grantedCount = category.permissions.where(granted.contains).length;
    final fullyGranted = category.available && grantedCount == total;
    final partial = category.available && grantedCount > 0 && !fullyGranted;
    final status = !category.available
        ? l10n.onboardingStatusNotSupported
        : fullyGranted
            ? l10n.onboardingStatusGranted
            : partial
                ? l10n.onboardingStatusPartiallyGranted(grantedCount, total)
                : category.isRequired
                    ? l10n.onboardingStatusRequired
                    : l10n.onboardingStatusOptional;

    return OpenVitalsCard(
      color: fullyGranted
          ? scheme.primaryContainer.withValues(alpha: 0.4)
          : scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _categoryTitle(l10n, category.id),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: fullyGranted
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (fullyGranted)
                  Icon(Icons.check_circle_outline, color: scheme.primary)
                else if (!category.available)
                  Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _categoryDescription(
                  l10n,
                  category.id,
                  available: category.available,
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            if (!fullyGranted && category.available)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.tonal(
                    onPressed: onGrant,
                    child: Text(partial ? l10n.actionReview : l10n.actionGrant),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.availability});

  final HealthConnectAvailability availability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final message = switch (availability) {
      HealthConnectAvailability.needsPlayStore =>
        l10n.onboardingHealthConnectNeedsPlayStore,
      HealthConnectAvailability.needsProviderUpdate =>
        l10n.onboardingHealthConnectUpdate,
      HealthConnectAvailability.notSupported =>
        l10n.onboardingHealthConnectNotSupported,
      HealthConnectAvailability.available => '',
    };
    return OpenVitalsCard(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onErrorContainer),
        ),
      ),
    );
  }
}

/// Category title, localized one-to-one from the Kotlin
/// `onboarding_category_*` strings, keyed by [OnboardingPermissionCategory.id].
String _categoryTitle(AppLocalizations l10n, String id) {
  switch (id) {
    case 'activity_sleep':
      return l10n.onboardingCategoryActivitySleep;
    case 'heart_recovery':
      return l10n.onboardingCategoryHeartRecovery;
    case 'vitals':
      return l10n.onboardingCategoryVitals;
    case 'body':
      return l10n.onboardingCategoryBody;
    case 'activity_extras':
      return l10n.onboardingCategoryActivityExtras;
    case 'nutrition_hydration':
      return l10n.onboardingCategoryNutritionHydration;
    case 'mindfulness':
      return l10n.onboardingCategoryMindfulness;
    case 'cycle_tracking':
      return l10n.onboardingCategoryCycleTracking;
    default:
      return id;
  }
}

/// Category description (the `onboarding_category_*_desc` strings). Mindfulness
/// falls back to its "requires a newer Health Connect version" copy when the
/// feature is unavailable.
String _categoryDescription(
  AppLocalizations l10n,
  String id, {
  required bool available,
}) {
  if (id == 'mindfulness' && !available) {
    return l10n.onboardingCategoryMindfulnessUnavailable;
  }
  switch (id) {
    case 'activity_sleep':
      return l10n.onboardingCategoryActivitySleepDesc;
    case 'heart_recovery':
      return l10n.onboardingCategoryHeartRecoveryDesc;
    case 'vitals':
      return l10n.onboardingCategoryVitalsDesc;
    case 'body':
      return l10n.onboardingCategoryBodyDesc;
    case 'activity_extras':
      return l10n.onboardingCategoryActivityExtrasDesc;
    case 'nutrition_hydration':
      return l10n.onboardingCategoryNutritionHydrationDesc;
    case 'mindfulness':
      return l10n.onboardingCategoryMindfulnessDesc;
    case 'cycle_tracking':
      return l10n.onboardingCategoryCycleTrackingDesc;
    default:
      return '';
  }
}
