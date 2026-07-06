import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Training-readiness detail pushed over the shell
/// (`/daily_readiness/training_readiness/:trainingReadinessDate`).
// TODO(phase5): replace with the real training-readiness detail.
class TrainingReadinessDetailsScreen extends StatelessWidget {
  const TrainingReadinessDetailsScreen({super.key, required this.date});

  /// ISO-8601 date argument (`yyyy-MM-dd`).
  final String date;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Training readiness',
        subtitle: 'Date: $date',
      );
}
