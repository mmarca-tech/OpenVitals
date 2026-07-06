import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Combined heart & vitals overview pushed over the shell (`/heart_vitals`).
// TODO(phase5): replace with the real heart & vitals overview.
class HeartVitalsOverviewScreen extends StatelessWidget {
  const HeartVitalsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Heart & Vitals');
}
