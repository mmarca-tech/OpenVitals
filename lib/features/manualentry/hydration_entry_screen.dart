import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Hydration manual-entry screen pushed over the shell. Backs three routes:
/// new entry, edit (carries [hydrationEntryId]) and log-drink (carries
/// [logDrinkId]).
// TODO(phase5): replace with the real hydration-entry form.
class HydrationEntryScreen extends StatelessWidget {
  const HydrationEntryScreen({
    super.key,
    this.hydrationEntryId,
    this.logDrinkId,
  });

  final String? hydrationEntryId;
  final String? logDrinkId;

  @override
  Widget build(BuildContext context) {
    final String subtitle;
    if (hydrationEntryId != null) {
      subtitle = 'Editing $hydrationEntryId';
    } else if (logDrinkId != null) {
      subtitle = 'Logging drink $logDrinkId';
    } else {
      subtitle = 'Coming soon';
    }
    return PlaceholderScreen(title: 'Hydration entry', subtitle: subtitle);
  }
}
