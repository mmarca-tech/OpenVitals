import 'package:flutter/material.dart';

import '../../navigation/app_routes.dart';

/// The top-level settings sections, ported from the Kotlin `SettingsSection`
/// enum (each maps to a card on the settings root + a pushed sub-screen).
enum SettingsSection {
  display(
    route: AppRoutes.settingsDisplay,
    title: 'Display',
    summary: 'Language, units, theme and colours',
    icon: Icons.settings_outlined,
  ),
  activities(
    route: AppRoutes.settingsActivities,
    title: 'Activities',
    summary: 'Week layout and activity preferences',
    icon: Icons.directions_run_outlined,
  ),
  sensors(
    route: AppRoutes.settingsSensors,
    title: 'Sensors',
    summary: 'Connect Bluetooth heart-rate sensors',
    icon: Icons.bluetooth,
  ),
  nutrition(
    route: AppRoutes.settingsNutrition,
    title: 'Nutrition',
    summary: 'Calorie source and hydration goal',
    icon: Icons.restaurant_outlined,
  ),
  recovery(
    route: AppRoutes.settingsRecovery,
    title: 'Recovery',
    summary: 'Sleep window and heart-rate thresholds',
    icon: Icons.favorite_border,
  ),
  dataImport(
    route: AppRoutes.settingsDataImport,
    title: 'Data import',
    summary: 'Import from Apple Health and .fit files',
    icon: Icons.folder_open_outlined,
  ),
  healthConnect(
    route: AppRoutes.settingsHealthConnect,
    title: 'Health Connect',
    summary: 'Sync, permissions and app lock',
    icon: Icons.health_and_safety_outlined,
  );

  const SettingsSection({
    required this.route,
    required this.title,
    required this.summary,
    required this.icon,
  });

  final String route;
  final String title;
  final String summary;
  final IconData icon;

  static SettingsSection? fromRoute(String route) {
    for (final section in values) {
      if (section.route == route) return section;
    }
    return null;
  }
}
