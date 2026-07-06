import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Dashboard nav-suite branch body (rendered inside the adaptive scaffold).
// TODO(phase5): replace with the real dashboard grid + widgets.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderBody(title: 'Dashboard');
}
