import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Body-measurement manual-entry screen pushed over the shell. Backs the
/// new-entry route (carries [bodyMeasurementType]) and the edit route (also
/// carries [bodyEntryId]).
// TODO(phase5): replace with the real body-measurement form.
class BodyMeasurementEntryScreen extends StatelessWidget {
  const BodyMeasurementEntryScreen({
    super.key,
    required this.bodyMeasurementType,
    this.bodyEntryId,
  });

  /// The `BodyMeasurementType` storage name (WEIGHT, HEIGHT, BODY_FAT, …).
  final String bodyMeasurementType;
  final String? bodyEntryId;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Body measurement',
        subtitle: bodyEntryId == null
            ? 'Type: $bodyMeasurementType'
            : 'Editing $bodyEntryId ($bodyMeasurementType)',
      );
}
