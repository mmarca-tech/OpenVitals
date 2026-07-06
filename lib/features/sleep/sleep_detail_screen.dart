import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Single sleep-session detail pushed over the shell (`/sleep_detail/:sleepId`).
// TODO(phase5): replace with the real sleep-session detail.
class SleepDetailScreen extends StatelessWidget {
  const SleepDetailScreen({super.key, required this.sleepId});

  final String sleepId;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Sleep session',
        subtitle: 'Session: $sleepId',
      );
}
