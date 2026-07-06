import 'package:flutter/material.dart';

import '../../navigation/app_routes.dart';
import '../../ui/components/placeholder_screen.dart';

/// Activity manual-entry / recording screen pushed over the shell. Backs the
/// new-entry route (with optional [mode]/[planId]/[activityTypeId] query args)
/// and the edit route (carries [activityEntryId]).
// TODO(phase5): replace with the real activity recording + manual-entry UI.
class ActivityEntryScreen extends StatelessWidget {
  const ActivityEntryScreen({
    super.key,
    this.mode,
    this.planId,
    this.activityTypeId,
    this.activityEntryId,
  });

  final ActivityEntryMode? mode;
  final String? planId;
  final String? activityTypeId;
  final String? activityEntryId;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (activityEntryId != null) 'editing $activityEntryId',
      if (mode != null) 'mode ${mode!.value}',
      if (planId != null) 'plan $planId',
      if (activityTypeId != null) 'type $activityTypeId',
    ];
    return PlaceholderScreen(
      title: 'Activity entry',
      subtitle: details.isEmpty ? 'Coming soon' : details.join(' · '),
    );
  }
}
