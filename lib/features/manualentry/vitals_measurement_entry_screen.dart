import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Vitals-measurement manual-entry screen pushed over the shell. Backs the
/// new-entry route (carries [vitalsMeasurementType]) and the edit route (also
/// carries [vitalsEntryId]).
// TODO(phase5): replace with the real vitals-measurement form.
class VitalsMeasurementEntryScreen extends StatelessWidget {
  const VitalsMeasurementEntryScreen({
    super.key,
    required this.vitalsMeasurementType,
    this.vitalsEntryId,
  });

  /// The `VitalsMeasurementType` storage name (BLOOD_PRESSURE, SPO2, …).
  final String vitalsMeasurementType;
  final String? vitalsEntryId;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Vitals measurement',
        subtitle: vitalsEntryId == null
            ? 'Type: $vitalsMeasurementType'
            : 'Editing $vitalsEntryId ($vitalsMeasurementType)',
      );
}
