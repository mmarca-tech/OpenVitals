import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Sleep section pushed over the shell (`/sleep`).
// TODO(phase5): replace with the real sleep overview.
class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderScreen(title: 'Sleep');
}
