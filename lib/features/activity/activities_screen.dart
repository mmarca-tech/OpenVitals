import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Activities nav-suite branch body (rendered inside the adaptive scaffold).
// TODO(phase5): replace with the real activities list + overview.
class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PlaceholderBody(title: 'Activities');
}
