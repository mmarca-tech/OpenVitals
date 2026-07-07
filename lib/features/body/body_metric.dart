import 'package:flutter/material.dart';

import '../../health/health_permissions.dart';
import '../../ui/theme/app_colors.dart';

/// The body-composition metric family surfaced by the shared body detail screen.
///
/// Port of the Kotlin `BodyMetric` enum (`BodyScreen.kt`), extended with the
/// derived FFMI metric (which the Kotlin dashboard routes onto the BMI screen but
/// which this port surfaces as its own detail screen). Each constant knows its
/// route id (the `DashboardMetricId.storageName` used by `/metric/:metricId`),
/// chrome (title/icon/accent), the Health Connect read permission the gate
/// requires, and the empty-state message.
enum BodyMetric {
  weight('WEIGHT', 'Weight', Icons.monitor_weight_outlined),
  height('HEIGHT', 'Height', Icons.straighten),
  bmi('BMI', 'BMI', Icons.monitor_weight_outlined),
  ffmi('FFMI', 'FFMI', Icons.fitness_center),
  bodyFat('BODY_FAT', 'Body fat', Icons.monitor_weight_outlined),
  leanMass('LEAN_MASS', 'Lean body mass', Icons.monitor_weight_outlined),
  bmr('BMR', 'Basal metabolic rate', Icons.local_fire_department_outlined),
  boneMass('BONE_MASS', 'Bone mass', Icons.monitor_weight_outlined),
  bodyWaterMass('BODY_WATER_MASS', 'Body water mass',
      Icons.monitor_weight_outlined);

  const BodyMetric(this.routeName, this.title, this.icon);

  /// The `DashboardMetricId.storageName` this metric is reached through on the
  /// `/metric/:metricId` route.
  final String routeName;
  final String title;
  final IconData icon;

  Color get accentColor {
    switch (this) {
      case BodyMetric.bodyFat:
      case BodyMetric.ffmi:
        return AppColors.bodyFat;
      case BodyMetric.bmr:
        return AppColors.calories;
      case BodyMetric.weight:
      case BodyMetric.height:
      case BodyMetric.bmi:
      case BodyMetric.leanMass:
      case BodyMetric.boneMass:
      case BodyMetric.bodyWaterMass:
        return AppColors.weight;
    }
  }

  /// The Health Connect read permission the [HealthConnectGate] requires. BMI /
  /// FFMI are derived from weight (+ height / body-fat), so they gate on weight.
  String get readPermission {
    switch (this) {
      case BodyMetric.weight:
      case BodyMetric.bmi:
        return HcPermissions.readWeight;
      case BodyMetric.height:
        return HcPermissions.readHeight;
      case BodyMetric.ffmi:
      case BodyMetric.bodyFat:
        return HcPermissions.readBodyFat;
      case BodyMetric.leanMass:
        return HcPermissions.readLeanMass;
      case BodyMetric.bmr:
        return HcPermissions.readBmr;
      case BodyMetric.boneMass:
        return HcPermissions.readBoneMass;
      case BodyMetric.bodyWaterMass:
        return HcPermissions.readBodyWaterMass;
    }
  }

  /// Message shown when the selected period has no readings.
  String get emptyMessage {
    switch (this) {
      case BodyMetric.weight:
        return 'No weight readings for this period.';
      case BodyMetric.height:
        return 'No height readings for this period.';
      case BodyMetric.bmi:
        return 'BMI needs a weight and a height reading.';
      case BodyMetric.ffmi:
        return 'FFMI needs weight, height, and body-fat readings.';
      case BodyMetric.bodyFat:
        return 'No body-fat readings for this period.';
      case BodyMetric.leanMass:
        return 'No lean body mass readings for this period.';
      case BodyMetric.bmr:
        return 'No basal metabolic rate readings for this period.';
      case BodyMetric.boneMass:
        return 'No bone mass readings for this period.';
      case BodyMetric.bodyWaterMass:
        return 'No body water mass readings for this period.';
    }
  }

  /// Resolves the body metric a `/metric/:metricId` argument maps to, or null
  /// when it belongs to another family. Mirrors the Kotlin `toBodyMetricOrNull`.
  static BodyMetric? fromRouteName(String? routeName) {
    if (routeName == null) return null;
    for (final metric in values) {
      if (metric.routeName == routeName) return metric;
    }
    return null;
  }
}
