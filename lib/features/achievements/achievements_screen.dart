import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Achievements screen pushed over the shell (`/achievements`).
// TODO(phase5): replace with the real achievements grid.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Achievements');
}
