import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Menstrual-cycle metric screen pushed over the shell (via `/metric/CYCLE`).
// TODO(phase5): replace with the real cycle overview.
class CycleScreen extends StatelessWidget {
  const CycleScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Cycle');
}
