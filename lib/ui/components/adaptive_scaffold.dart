import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../navigation/app_routes.dart';

/// The OpenVitals home scaffold — a Material 3 top app bar over the dashboard.
///
/// Mirrors the Kotlin `OpenVitalsAdaptiveScaffold`: the app has **no bottom
/// navigation**. The dashboard is the home, and every other destination is
/// reached from the top-bar actions (Mindfulness / Achievements / Settings) or
/// from in-screen actions (the Activities section, the Log / Start buttons,
/// metric cards). Those destinations are pushed onto the root navigator and get
/// their own back-enabled app bar.
class OpenVitalsHomeScaffold extends StatelessWidget {
  const OpenVitalsHomeScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: l10n.screenMindfulness,
            icon: const Icon(Icons.self_improvement_outlined),
            onPressed: () => context.push(AppRoutes.mindfulnessEntry),
          ),
          IconButton(
            tooltip: l10n.screenAchievements,
            icon: const Icon(Icons.workspace_premium_outlined),
            onPressed: () => context.push(AppRoutes.achievements),
          ),
          IconButton(
            tooltip: l10n.screenSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: child,
    );
  }
}
