import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Hydration metric screen pushed over the shell (via `/metric/HYDRATION`).
// TODO(phase5): replace with the real hydration overview.
class HydrationScreen extends StatelessWidget {
  const HydrationScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Hydration');
}
