import 'package:flutter/material.dart';

import '../../ui/components/placeholder_screen.dart';

/// Heart/vitals single-metric detail pushed over the shell via
/// `/metric/:metricId` (avg HR, resting HR, HRV, blood pressure, SpO2, VO2 max,
/// respiratory rate, body/skin temperature, blood glucose).
// TODO(phase5): replace with the real per-metric heart/vitals detail.
class HeartMetricScreen extends StatelessWidget {
  const HeartMetricScreen({super.key, required this.metricId});

  final String metricId;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Heart & Vitals',
        subtitle: 'Metric: $metricId',
      );
}
