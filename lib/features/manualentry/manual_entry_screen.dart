import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Add-entry nav-suite branch body (rendered inside the adaptive scaffold).
// TODO(phase5): replace with the real manual-entry hub grid.
class ManualEntryScreen extends StatelessWidget {
  const ManualEntryScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderBody(title: 'Add entry');
}
