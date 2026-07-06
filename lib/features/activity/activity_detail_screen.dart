import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Single-activity detail pushed over the shell (`/activity_detail/:activityId`).
// TODO(phase5): replace with the real activity detail (map, laps, HR, …).
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Activity',
        subtitle: 'Activity: $activityId',
      );
}
