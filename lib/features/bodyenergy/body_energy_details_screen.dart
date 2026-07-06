import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Body-energy timeline detail pushed over the shell
/// (`/daily_readiness/body_energy/:bodyEnergyDate`).
// TODO(phase5): replace with the real body-energy timeline.
class BodyEnergyDetailsScreen extends StatelessWidget {
  const BodyEnergyDetailsScreen({super.key, required this.date});

  /// ISO-8601 date argument (`yyyy-MM-dd`).
  final String date;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Body energy',
        subtitle: 'Date: $date',
      );
}
