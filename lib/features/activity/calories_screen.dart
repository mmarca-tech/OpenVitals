import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Calories section pushed over the shell (`/calories`).
// TODO(phase5): replace with the real calories overview.
class CaloriesScreen extends StatelessWidget {
  const CaloriesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Calories');
}
