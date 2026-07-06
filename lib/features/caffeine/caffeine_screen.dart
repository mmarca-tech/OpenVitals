import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Caffeine metric screen pushed over the shell (via `/metric/CAFFEINE`).
// TODO(phase5): replace with the real caffeine overview.
class CaffeineScreen extends StatelessWidget {
  const CaffeineScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Caffeine');
}
