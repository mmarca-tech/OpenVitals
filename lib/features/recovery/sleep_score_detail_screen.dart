import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Sleep-score detail pushed over the shell (`/recovery/sleep_score`).
// TODO(phase5): replace with the real sleep-score detail.
class SleepScoreDetailScreen extends StatelessWidget {
  const SleepScoreDetailScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Sleep score');
}
