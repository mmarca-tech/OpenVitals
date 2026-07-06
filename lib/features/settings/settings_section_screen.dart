import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// A settings sub-section pushed over the shell (Display, Sensors, Recovery, …).
// TODO(phase5): replace with the real section content, keyed by [title].
class SettingsSectionScreen extends StatelessWidget {
  const SettingsSectionScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(title: title);
}
