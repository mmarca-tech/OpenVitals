import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Onboarding flow, shown as the start destination when onboarding is not yet
/// complete. Rendered full-screen outside the adaptive shell.
///
/// [onOnboardingComplete] is invoked when the user finishes onboarding; the app
/// shell persists the flag and routes on to the dashboard.
// TODO(phase5): replace with the real multi-step onboarding + permissions flow.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.onOnboardingComplete});

  final VoidCallback? onOnboardingComplete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PlaceholderBody(
              title: 'Welcome to OpenVitals',
              subtitle: 'Onboarding coming soon',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onOnboardingComplete,
              child: const Text('Get started'),
            ),
          ],
        ),
      ),
    );
  }
}
