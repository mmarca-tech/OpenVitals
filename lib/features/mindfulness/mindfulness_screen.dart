import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Mindfulness metric screen pushed over the shell (via `/metric/MINDFULNESS`).
// TODO(phase5): replace with the real mindfulness overview.
class MindfulnessScreen extends StatelessWidget {
  const MindfulnessScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Mindfulness');
}
