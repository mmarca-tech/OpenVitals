import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Nutrition section pushed over the shell (`/nutrition`).
// TODO(phase5): replace with the real nutrition overview.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Nutrition');
}
