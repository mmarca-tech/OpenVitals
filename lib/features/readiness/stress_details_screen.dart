import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Stress-tracking detail pushed over the shell
/// (`/daily_readiness/stress/:stressDate`).
// TODO(phase5): replace with the real stress-tracking detail.
class StressDetailsScreen extends StatelessWidget {
  const StressDetailsScreen({super.key, required this.date});

  /// ISO-8601 date argument (`yyyy-MM-dd`).
  final String date;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Stress',
        subtitle: 'Date: $date',
      );
}
