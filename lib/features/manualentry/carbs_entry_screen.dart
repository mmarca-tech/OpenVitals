import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Carbs manual-entry screen pushed over the shell (`/manual_entry/carbs`).
// TODO(phase5): replace with the real carbs-entry form.
class CarbsEntryScreen extends StatelessWidget {
  const CarbsEntryScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Carbs entry');
}
