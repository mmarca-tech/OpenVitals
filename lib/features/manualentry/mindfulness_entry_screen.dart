import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Mindfulness manual-entry screen pushed over the shell. Handles both the
/// new-entry route and the edit route (which carries a [mindfulnessEntryId]).
// TODO(phase5): replace with the real mindfulness-entry form.
class MindfulnessEntryScreen extends StatelessWidget {
  const MindfulnessEntryScreen({super.key, this.mindfulnessEntryId});

  final String? mindfulnessEntryId;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Mindfulness entry',
        subtitle: mindfulnessEntryId == null
            ? 'Coming soon'
            : 'Editing $mindfulnessEntryId',
      );
}
